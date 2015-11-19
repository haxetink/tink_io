package tink.io;

import haxe.io.*;
import tink.io.Buffer;
import tink.io.IdealSource;
import tink.io.Pipe;
import tink.io.Sink;
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
    
  @:from static function fromString(s:String):Source
    return fromBytes(Bytes.ofString(s));
    
}

interface SourceObject {
  function prepend(other:Source):Source;
  function append(other:Source):Source;
  function read(into:Buffer):Surprise<Progress, Error>;
  function pipeTo(sink:Sink):Future<PipeResult>;
  function close():Surprise<Noise, Error>;
  function parse<T>(parser:StreamParser<T>):Surprise<{ data:T, rest: Source }, Error>;
  function parseWhile<T>(parser:StreamParser<T>, cond:T->Future<Bool>):Surprise<Source, Error>;
}

#if nodejs
class NodeSource extends SourceBase {
  
  var target:js.node.stream.Readable.IReadable;
  var name:String;
  var end:Surprise<Progress, Error>;
  
  var rest:Bytes;
  var pos:Int;
  
  public function new(target, name) {
    
    this.target = target;
    this.name = name;
    
    end = Future.async(function (cb) {
      target.once('end', function () cb(Success(Progress.EOF)));
      target.once('error', function (e) cb(Failure(Error.reporter('Error while reading from $name')(e))));
    });
    
  }
  
  function readBytes(into:Bytes, offset:Int, length:Int) {
    
    if (length > rest.length - pos)
      length = rest.length - pos;
      
    into.blit(offset, rest, pos, length);
    
    pos += length;
    
    if (pos == rest.length)
      rest = null;
    
    return length;
  }
  
  override public function read(into:Buffer):Surprise<Progress, Error> {
    if (rest == null) {
      var chunk = target.read();
      if (chunk == null)
        return end || Future.async(function (cb) 
          target.once('readable', function () cb(Noise))
        ).flatMap(function (_) return read(into));
        
      rest = Bytes.ofData(cast chunk);
      pos = 0;
    }
    
    return Future.sync(into.tryReadingFrom(name, this));
  }
  
  override public function close():Surprise<Noise, Error> {
    return Future.sync(Success(Noise));
  }
}
#end
#if nodejsold
class NodeSource extends AsyncSource {
  var target:js.node.stream.Readable.IReadable;
  var name:String;
  public function new(target, name) {
    this.target = target;
    this.name = name;
    super(
      function (onChunk, onEnd) { 
        
        target.on('data', function handleChunk(blob:Dynamic) onChunk.trigger(Bytes.ofData(blob)));
        target.on('end', function handleEnd() { onEnd.trigger(Success(Noise)); });
        target.on('error', function handleError(e) onEnd.trigger(Failure(new Error('Error $e on $name'))));
        
      }, 
      closeTarget
    );
  }
  
  function closeTarget() {
    try {
      untyped target.close(); //Not documented, but seems available - except when it isn't ... hence the pokemon clause \o/ https://github.com/nodejs/node-v0.x-archive/blob/cfcb1de130867197cbc9c6012b7e84e08e53d032/lib/fs.js#L1597-L1620
    }
    catch (e:Dynamic) {}
  }
  
  public function toString() 
    return this.name;
  
  override public function pipeTo(dest:Sink):Future<PipeResult> {
    return 
      if (Std.is(dest, NodeSink)) {
        var dest = (cast dest : NodeSink);
        var writable = @:privateAccess dest.target;
        
        target.pipe(writable, { end: false } );
        
        return Future.async(function (cb) {
          @:privateAccess dest.next({
            unpipe: function (s) if (s == target) cb(new PipeResult(-1, AllWritten)),
          });
        });
      }
      else super.pipeTo(dest);
  }
}
#end

class AsyncSource extends SourceBase {
  var data:SyntheticIdealSource;
  var end:Surprise<Noise, Error>;
  var onError:Surprise<Progress, Error>;
  var _close:Void->Void;
  
  public function new(f:SignalTrigger<Bytes>->FutureTrigger<Outcome<Noise, Error>>->Void, close) {
    this.data = IdealSource.create();
    _close = close;
    var onData = Signal.trigger(),
        onEnd = Future.trigger();
        
    onData.asSignal().handle(data.write);
    end = onEnd.asFuture();
    end.handle(function (e) {
      data.close();
    });
    onError = Future.async(function (cb) end.handle(function (o) switch o {
      case Failure(e): cb(Failure(e));
      default:
    }));
    f(onData, onEnd);
  }
    
  override public function read(into:Buffer):Surprise<Progress, Error>
    return 
      data.read(into) || onError;
  
  override public function close():Surprise<Noise, Error> {
    _close();  
    return data.close();
  }

}

class SourceBase implements SourceObject {
  public function prepend(other:Source):Source
    return CompoundSource.of(other, this);
  public function append(other:Source):Source
    return CompoundSource.of(this, other);
    
  public function read(into:Buffer):Surprise<Progress, Error>
    return throw 'not implemented';
  
  public function close():Surprise<Noise, Error>
    return throw 'not implemented';
  
  public function pipeTo(dest:Sink):Future<PipeResult>
    return Pipe.make(this, dest);
    
  public function parse<T>(parser:StreamParser<T>):Surprise<{ data:T, rest: Source }, Error> {
    var ret = null;
    return 
      parseWhile(parser, function (x) { ret = x; return Future.sync(false); } ) 
      >> function (s:Source) return { data: ret, rest: s };
  }      
    
  public function parseWhile<T>(parser:StreamParser<T>, cond):Surprise<Source, Error>
    return Future.async(function (cb:Outcome<Source, Error>->Void) {
      var ret = null;
      var sink = new ParserSink(parser, cond);
      
      pipeTo(sink).handle(function (res) switch res.status {
        case AllWritten:
          cb(Success((Empty.instance : Source)));
        case SinkEnded(rest):
          cb(Success((rest.content() : Source).append(this)));
        case SinkFailed(e, _):
          cb(Failure(e));
        case SourceFailed(e):
          cb(Failure(e));
      });
    });    
}

class FutureSource extends SourceBase {
  var s:Surprise<Source, Error>;
  public function new(s)
    this.s = s;
    
  override public function read(into:Buffer):Surprise<Progress, Error>
    return s >> function (s:Source) return s.read(into);
    
  override public function close():Surprise<Noise, Error>
    return s >> function (s:Source) return s.close();
  
  public function toString() {
    var ret = 'PENDING';
    s.handle(function (o) ret = Std.string(o));
    return '[FutureSource $ret]';
  }
    
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
  
  public function toString()
    return name;

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
  
  static public function of(a:Source, b:Source) //TODO: consider dealing with null
    return new CompoundSource(
      switch [Std.instance(a, CompoundSource), Std.instance(b, CompoundSource)] {
        case [null, null]: 
          [a, b];
        case [null, { parts: p }]: 
          [a].concat(p);  
        case [{ parts: p }, null]: 
          p.concat([b]);
        case [{ parts: p1 }, { parts: p2 }]:
          p1.concat(p2);
      }
    );
}