package tink.io;

import haxe.io.Bytes;
import tink.io.Sink;
import tink.io.Source;

using tink.CoreApi;

class Pipe {
  var buffer:Buffer;
  var source:Source;
  var dest:Sink;
  var result:FutureTrigger<PipeResult<Error, Error>>;
  var onDone:Pipe-> Void;
  var autoClose:Bool;
  
  function new(source, dest, ?buffer, ?autoClose = false, ?onDone) {
    
    if (buffer == null)
      buffer = Buffer.alloc(17);
      
    this.autoClose = autoClose;
		this.source = source;
		this.dest = dest;
		
		this.buffer = buffer;
		this.result = Future.trigger();
		this.onDone = onDone;
  }
  
  function terminate(s) {
    result.trigger(s);
    if (onDone != null)
      onDone(this);
  }
  
	function read()
		source.read(buffer).handle(function (o) switch o {
			case Success(_.isEof => true):
        source.close();
        buffer.seal();
				flush();
			case Success(v):
        flush();
			case Failure(e):
        terminate(SourceFailed(e));
		});
    
	function flush(?repeat = 1) {
    if (buffer.writable || !autoClose) {
      dest.write(buffer).handle(function (o) switch o {
        case Success(_.isEof => true):
          terminate(if (buffer.available > 0) SinkEnded(buffer) else AllWritten);
        case Success(v):
          if (repeat > 0)
            flush(repeat - 1);
          else
            if (buffer.writable) //TODO: find a good threshold
              read();
            else 
              flush();
        case Failure(f):
          source.close();
          terminate(SinkFailed(f, buffer));
      });
    }
    else
      dest.finish(buffer).handle(function (o) switch o {
        case Success(_):
          terminate(if (buffer.available > 0) SinkEnded(buffer) else AllWritten);
        case Failure(f):
          terminate(SinkFailed(f, buffer));
      });
  }
  
  static var queue = [];
  
  static public function make<In, Out>(from:PipePart<In, Source>, to:PipePart<Out, Sink>, ?buffer, ?options: { ?end: Bool }):Future<PipeResult<In, Out>> {
		var p = new Pipe(from, to, buffer, options != null && options.end, function (p) {
      @:privateAccess p.buffer.dispose();//TODO: this whole business should be less hacky
    });
    p.read();
		return cast p.result.asFuture();     
  }
}

enum PipeResult<In, Out> {
  AllWritten:PipeResult<In, Out>;
  SinkFailed(e:Error, rest:Buffer):PipeResult<In, Error>;
  SinkEnded(rest:Buffer):PipeResult<In, Error>;
  SourceFailed(e:Error):PipeResult<Error, Out>;
}

abstract PipePart<Quality, Value>(Value) to Value {
  
  inline function new(x) this = x;
  
  @:from static inline function ofIdealSource(s:IdealSource)
    return new PipePart<Noise, Source>(s); 
    
  @:from static inline function ofSource(s:Source)
    return new PipePart<Error, Source>(s); 
    
  @:from static inline function ofIdealSink(s:IdealSink)
    return new PipePart<Noise, IdealSink>(s);
    
  @:from static inline function ofSink(s:Sink)
    return new PipePart<Error, Sink>(s); 
}