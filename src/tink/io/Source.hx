package tink.io;

import haxe.io.*;
import tink.io.Buffer;
import tink.io.IdealSource;
import tink.io.Pipe;
import tink.io.Sink;
import tink.io.Source.NodeSource;
import tink.io.Worker;

using tink.CoreApi;

@:forward
abstract Source(SourceObject) from SourceObject to SourceObject {
  
  #if nodejs
  static public function ofNodeStream(r:js.node.stream.Readable.IReadable, name)
    return new NodeSource(r, name);
  #end
  
  static public function async(f, close) 
    return new AsyncSource(f, close);
  
  static public function failure(e:Error):Source
    return new FailedSource(e);
  
  static public function ofInput(name:String, input:Input, ?worker:Worker):Source
    return new StdSource(name, input, worker);
    
  @:from static public function flatten(s:Surprise<Source, Error>):Source
    return new FutureSource(s);
    
  @:from static function fromBytes(b:Bytes):Source
    return tink.io.IdealSource.ofBytes(b);
    
}

interface SourceObject {
  function append(other:Source):Source;
  function read(into:Buffer):Surprise<Progress, Error>;
  function pipeTo(sink:Sink):Future<PipeResult>;
  function close():Surprise<Noise, Error>;
}

#if nodejs
class NodeSource extends AsyncSource {
  var target:js.node.stream.Readable.IReadable;
  public function new(target, name) {
    this.target = target;
    super(
      function (addChunk, end) { 
        
        target.on('data', function handleChunk(blob:Dynamic) addChunk(Bytes.ofData(blob)));
        target.on('end', function handleEnd() end(Success(Noise)));
        target.on('error', function handleError(e) end(Failure(new Error('Error $e on $name'))));
        
      }, 
      untyped target.close //Not documented, but very much available https://github.com/nodejs/node-v0.x-archive/blob/cfcb1de130867197cbc9c6012b7e84e08e53d032/lib/fs.js#L1597-L1620
    );
  }
  //override public function pipeTo(dest:Sink):Future<PipeResult> {
    //if (Std.is(dest, NodeSource))
      //target.pipe(@:privateAccess (cast dest : NodeSource).target);
  //}
}
#end

class AsyncSource extends SourceBase {
  var data:SyntheticIdealSource;
  var end:Outcome<Noise, Error>;
  var _close:Void->Void;
  
  public function new(f:(Bytes->Void)->(Outcome<Noise, Error>->Void)->Void, close) {
    this.data = IdealSource.create();
    _close = close;
    f(addChunk, finish);
  }
    
  override public function read(into:Buffer):Surprise<Progress, Error>
    return 
      data.readSafely(into).map( 
        function (p:Progress) 
          return
            if (p.isEof)
              switch end {
                case null:
                  end = Success(Noise);
                  Success(p);
                case Success(_): Success(p);
                case Failure(e): Failure(e);
              }
            else
              Success(p)
      );
  
  override public function close():Surprise<Noise, Error> {
    if (end != null)
      this.end = Success(Noise);
    _close();  
    return data.close();
  }
  
  function addChunk(b:Bytes)
    data.write(b);
  
  function finish(with) {
    if (end != null)
      this.end = with;
    data.end();
  }
}

class SourceBase implements SourceObject {
  
  public function append(other:Source):Source
    return CompoundSource.of(this, other);
    
  public function read(into:Buffer):Surprise<Progress, Error>
    return throw 'not implemented';
  
  public function close():Surprise<Noise, Error>
    return throw 'not implemented';
  
  public function pipeTo(dest:Sink):Future<PipeResult>
    return Pipe.make(this, dest);
}

class FutureSource extends SourceBase {
  var s:Surprise<Source, Error>;
  public function new(s)
    this.s = s;
    
  override public function read(into:Buffer):Surprise<Progress, Error>
    return s >> function (s:Source) return s.read(into);
    
  override public function close():Surprise<Noise, Error>
    return s >> function (s:Source) return s.close();
  
}

class FailedSource extends SourceBase {
  var error:Error;
  
  public function new(error)
    this.error = error;
    
  override public function read(into:Buffer)
    return Future.sync(Failure(error));      
    
  override public function close() {
    return Future.sync(Failure(error));
  }
}

class StdSource extends SourceBase {
  
  var name:String;
  var target:Input;
  var worker:Worker;
  
  public function new(name, target, ?worker) {
    this.name = name;
    this.target = target;
    this.worker = worker;
  }
    
  override public function read(into:Buffer):Surprise<Progress, Error>
    return worker.work(function () return into.tryReadingFrom(name, target));
  
  override public function close() {
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

class CompoundSource extends SourceBase {
  var parts:Array<Source>;
  public function new(parts)
    this.parts = parts;
  
  override public function append(other:Source):Source 
    return of(this, other);
    
  override public function close():Surprise<Noise, Error> {
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
  
  override public function read(into:Buffer):Surprise<Progress, Error>
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