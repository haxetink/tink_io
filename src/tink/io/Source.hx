package tink.io;

import haxe.io.Bytes;
import haxe.io.BytesData;
import haxe.io.Input;
import tink.io.Worker;

using tink.CoreApi;

@:forward
abstract Source(SourceObject) from SourceObject to SourceObject {
  
  static public function ofInput(name:String, input:Input, ?worker:Worker)
    return new StdSource(name, input, worker);
    
  @:from static function fromBytes(b:Bytes):Source
    return tink.io.IdealSource.ofBytes(b);
    
}

interface SourceObject {
  function append(other:Source):Source;
  function read(into:Buffer):Surprise<Progress, Error>;
  function close():Surprise<Noise, Error>;
}

class SourceBase implements SourceObject {
  
  public function append(other:Source)
    return CompoundSource.of(this, other);
    
  public function read(into:Buffer)
    return throw 'not implemented';
  
  public function close()
    return throw 'not implemented';
  
}

class StdSource implements SourceObject {
  
  var name:String;
  var target:Input;
  var worker:Worker;
  
  public function new(name, target, ?worker) {
    this.name = name;
    this.target = target;
    this.worker = worker;
  }

  public inline function append(other:Source):Source 
    return CompoundSource.of(this, other);
    
  public function read(into:Buffer):Surprise<Progress, Error>
    return worker.work(function () return into.tryReadingFrom(name, target));
  
  public function close() {
    return 
      worker.work(function () 
        return Error.catchExceptions(
          function () {
            target.close();
            return Noise;
          },
          Error.reporter('Failed to close $name')
        )
      );
  }

}

class CompoundSource implements SourceObject {
  var parts:Array<Source>;
  public function new(parts)
    this.parts = parts;
  
  public function append(other:Source):Source 
    return of(this, other);
    
  public function close():Surprise<Noise, Error> {
		if (parts.length == 0) return Future.sync(Success(Noise));
		var ret = Future.ofMany([
      for (p in parts) 
        p.close()
    ]);
		parts = [];
    return ret.map(function (outcomes) {
      var failures = [];
      for (o in outcomes)
        switch o {
          case Failure(f):
            failures.push(f);
          default:
        }
      
      return switch failures {
        case []: 
          Success(Noise);
        default: 
          Failure(Error.withData('Error closing sources', failures));
      }
    });
  }
  
  public function read(into:Buffer):Surprise<Progress, Error>
		return switch parts {
			case []: 
				Future.sync(Success(Progress.EOF));
			default:
				parts[0].read(into).flatMap(
					function (o) return switch o {
						case Success(_.isEof => true):
							parts.shift().close();
							read(into);//Technically a huge array of empty synchronous sources could cause a stack overflow, but let's be optimistic for once!
						default:
							Future.sync(o);
					}
				);  
    }
  
  static public function of(a:Source, b:Source) 
    return new CompoundSource(
      switch [Std.instance(a, CompoundSource), Std.instance(b, CompoundSource)] {
        case [null, null]: 
          [a, b];
        case [null, { parts: p } ]: 
          [a].concat(p);  
        case [{ parts: p }, null]: 
          p.concat([b]);
        case [{ parts: p1 }, { parts: p2 }]:
          p1.concat(p2);
      }
    );
}