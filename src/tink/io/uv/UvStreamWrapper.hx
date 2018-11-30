package tink.io.uv;

import uv.*;
import uv.Uv;
import cpp.*;
import tink.Chunk;
import haxe.io.Bytes;

using tink.CoreApi;

private typedef Options = {
  source:{name:String, ?onEnd:Void->Void},
  sink:{name:String, ?onEnd:Void->Void},
}

class UvStreamWrapper {
  
  var handle:Stream;
  var onWriteEnd:Void->Void;
  var onReadEnd:Void->Void;
  
  var readable:Bool;
  var writable:Bool;
  
  var nextRead:FutureTrigger<Outcome<Null<Chunk>, Error>>;
  var id:Int;
  
  static var ids:Int = 0;
  
  public static function wrap(handle, options:Options) {
    var wrapper = new UvStreamWrapper(handle, options.sink.onEnd, options.source.onEnd);
    return new Pair(
      new UvStreamSource(options.source.name, wrapper),
      new UvStreamSink(options.sink.name, wrapper)
    );
  }
  
  function new(handle, onWriteEnd:Void->Void, onReadEnd:Void->Void) {
    this.id = ids++;
    this.handle = handle;
    handle.setData(this);
    this.onWriteEnd = onWriteEnd;
    this.onReadEnd = onReadEnd;
    readable = handle.isReadable();
    writable = handle.isWritable();
    nextRead = Future.trigger();
    debug('new');
  }
  
  public function read():Promise<Null<Chunk>> {
    if(handle != null && readable) {
      switch handle.readStart(Callable.fromStaticFunction(onAlloc), Callable.fromStaticFunction(onRead)) {
        case 0: // ok
        case code: nextRead.trigger(Failure(new Error(code, Uv.err_name(code))));
      }
    } else {
      nextRead.trigger(Failure(new Error('Stream is not readable')));
      nextRead = Future.trigger();
    }
    return nextRead;
  }
  
  public function write(chunk:Chunk):Promise<Noise> {
    return if(handle != null && writable) {
      var trigger = Future.trigger();
      var req = new Write();
      var buf = new Buf(chunk.length);
      req.setData(new Pair(buf, trigger));
      buf.copyFromBytes(chunk);
      switch handle.write(req, buf, 1, Callable.fromStaticFunction(onWrite)) {
        case 0: // ok
        case code: trigger.trigger(Failure(new Error(code, Uv.err_name(code))));
      }
      trigger;
    } else {
      Future.sync(Failure(new Error('Stream is not writable')));
    }
  }
  
  public function shutdown():Promise<Noise> {
    debug('shutdown');
    writable = false;
    return if(handle != null) {
      var trigger = Future.trigger();
      var req = new Shutdown();
      req.setData(trigger);
      switch handle.shutdown(req, Callable.fromStaticFunction(onShutdown)) {
        case 0:
        case code: trigger.trigger(Failure(new Error(code, Uv.err_name(code))));
      }
      trigger;
    } else {
      Future.sync(Failure(new Error('Stream already closed')));
    }
  }
  
  public function close() {
    debug('close');
    writable = readable = false;
    if(handle != null) {
      handle.asHandle().close(Callable.fromStaticFunction(onClose));
      handle = null;
    }
  }
  
  function endRead() {
    readable = false;
    if(onReadEnd != null) {
      onReadEnd();
      onReadEnd = null;
    }
  }
  
  function endWrite() {
    writable = false;
    if(onWriteEnd != null) {
      onWriteEnd();
      onWriteEnd = null;
    }
  }
  
  static function onAlloc(handle:RawPointer<Handle_t>, suggestedSize:Size_t, buf:RawPointer<Buf_t>):Void {
    Buf.fromRaw(buf).alloc(cast suggestedSize);
  }
  
  static function onRead(handle:RawPointer<Stream_t>, nread:SSize_t, buf:RawConstPointer<Buf_t>):Void {
    var handle:Stream = handle;
    var wrapper:UvStreamWrapper = handle.getData();
    var trigger = wrapper.nextRead;
    wrapper.nextRead = Future.trigger();
    var nread:Int = cast nread;
    
    if(nread > 0) {
      handle.readStop();
      var bytes = Bytes.alloc(nread);
      Buf.unmanaged(buf).copyToBytes(bytes, nread);
      trigger.trigger(Success((bytes:Chunk)));
    }
    
    if(nread < 0) {
      trigger.trigger(nread == Uv.EOF ? Success(null) : Failure(new Error(Uv.err_name(nread))));
      wrapper.endRead();
      if(!wrapper.writable) wrapper.close();
    }
    
    if(nread == 0) {
      trigger.trigger(Success(Chunk.EMPTY));
    }
    
    Buf.unmanaged(buf).free();
  }
  
  static function onWrite(req:RawPointer<Write_t>, status:Int) {
    var write:Write = req;
    var pair:Pair<Buf, FutureTrigger<Outcome<Noise, Error>>> = write.getData();
    var buf = pair.a;
    var trigger = pair.b;
    buf.destroy();
    write.destroy();
    trigger.trigger(status == 0 ? Success(Noise) : Failure(new Error(Uv.err_name(status))));
  }
  
  static function onShutdown(req:RawPointer<Shutdown_t>, status:Int) {
    var req:uv.Shutdown = req;
    var wrapper:UvStreamWrapper = req.handle.getData();
    var trigger:FutureTrigger<Outcome<Noise, Error>> = req.getData();
    req.destroy();
    trigger.trigger(status == 0 ? Success(Noise) : Failure(new Error(status, Uv.err_name(status))));
    wrapper.endWrite();
    if(!wrapper.readable) wrapper.close();
  }
  
  static function onClose(handle:RawPointer<Handle_t>) {
    var wrapper:UvStreamWrapper = Stream.fromRawHandle(handle).getData();
    wrapper.handle.destroy();
    wrapper.handle = null;
    wrapper.endRead();
    wrapper.endWrite();
    wrapper.debug('closed');
  }
  
  inline function debug(msg) {
    // trace('$msg (#$id writable: $writable, readable: $readable)');
  }
}