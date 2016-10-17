package tink.io;

import haxe.io.Bytes;
import tink.io.Sink;
import tink.io.Source;

using tink.CoreApi;

class Pipe {
  var buffer:Buffer;
  var source:Source;
  var dest:Sink;
  var onDone:Buffer->PipeResult<Dynamic, Dynamic>->Void;
  var autoClose:Bool;
  var bufferWidth:Int;
  
  function new(source, dest, ?bufferWidth, ?autoClose = false, onDone) {
          
    this.bufferWidth = 
      if (bufferWidth != null) bufferWidth;
      else Buffer.DEFAULT_WIDTH;
      
    this.autoClose = autoClose;
    this.source = source;
    this.dest = dest;
    
    this.onDone = onDone;
  }
  
  function terminate(s) {
    onDone(buffer, s);
    releaseBuffer();
  }
  
  static var suspended = 
    #if tink_concurrent
      new tink.concurrent.Queue();
    #else
      new List();
    #end
  
  dynamic function releaseBuffer() {}
    
  function suspend() {
    if (this.bufferWidth > 0) 
      switch suspended.pop() {
        case null: read();
        case next:
          releaseBuffer();
          suspended.add(this);
          next.resume();
      }
    else read();
  }
  
  function resume() {
    if (this.buffer == null) {
      this.buffer = Buffer.alloc(this.bufferWidth);
      releaseBuffer = this.buffer.retain();
    }
    this.read();
  }
  
  function read()
    source.read(buffer).handle(function (o) switch o {
      case Success(_.isEof => true):
        source.close();
        buffer.seal();
        flush();
      case Success(v):
        if (v == 0 && buffer.available == 0)
          suspend();
        else
          flush();
      case Failure(e):
        terminate(SourceFailed(e));
    });
    
  function flush(?repeat = 1) {
    if (buffer.writable || !autoClose) {
      dest.write(buffer).handle(function (o) switch o {
        case Success(_.isEof => true):
          terminate(if (buffer.available > 0) SinkEnded else AllWritten);
        case Success(v):
          if (repeat > 0)
            flush(repeat - (v == 0 ? 1 : 0));
          else
            if (buffer.writable) //TODO: find a good threshold
              read();
            else 
              flush();
        case Failure(f):
          source.close();
          terminate(SinkFailed(f));
      });
    }
    else
      dest.finish(buffer).handle(function (o) switch o {
        case Success(_):
          terminate(if (buffer.available > 0) SinkEnded else AllWritten);
        case Failure(f):
          terminate(SinkFailed(f));
      });
  }
    
  static public function make<In, Out>(from:PipePart<In, Source>, to:PipePart<Out, Sink>, ?bufferWidth:Int, ?options: { ?end: Bool }, cb:Buffer->PipeResult<In, Out>->Void) {
    new Pipe(from, to, bufferWidth, options != null && options.end, function (buf, res) {
      cb(buf, cast res);
    }).resume();
  }
}

enum PipeResult<In, Out> {
  AllWritten:PipeResult<In, Out>;
  SinkFailed(e:Error):PipeResult<In, Error>;
  SinkEnded:PipeResult<In, Error>;
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
