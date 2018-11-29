package tink.io.uv;

import uv.Uv;
import cpp.*;
import haxe.io.*;
import tink.streams.Stream;

using tink.CoreApi;

class UvStreamSource extends Generator<Chunk, Error> {
  var name:String;
  var trigger:FutureTrigger<Step<Chunk, Error>>;
  
  public function new(name:String, handle:uv.Stream) {
    super(trigger = Future.trigger());
    this.name = name;
    handle.setData(this);
    handle.readStart(Callable.fromStaticFunction(alloc), Callable.fromStaticFunction(read));
  }
  
  static function alloc(handle:RawPointer<Handle_t>, suggestedSize:Size_t, buf:RawPointer<Buf_t>):Void {
    uv.Buf.fromRaw(buf).alloc(cast suggestedSize);
  }
  
  static function read(handle:RawPointer<Stream_t>, nread:SSize_t, buf:RawConstPointer<Buf_t>):Void {
    var handle:uv.Stream = handle;
    var source:UvStreamSource = handle.getData();
    var nread:Int = cast nread;
    
    if(nread > 0) {
      handle.readStop();
      var bytes = Bytes.alloc(nread);
      uv.Buf.unmanaged(buf).copyToBytes(bytes, nread);
      source.trigger.trigger(Link((bytes:Chunk), new UvStreamSource(source.name, handle)));
    }
    
    if(nread < 0) {
      if(nread == Uv.EOF) {
        source.trigger.trigger(End);
      } else {
        source.trigger.trigger(Fail(new Error(Uv.err_name(nread))));
      }
      
      if(!handle.asHandle().isClosing()) {
        handle.asHandle().close(Callable.fromStaticFunction(onClose));
        handle = null;
      }
    }
    
    uv.Buf.unmanaged(buf).free();
  }
  
	static function onClose(handle:RawPointer<Handle_t>) {
		uv.Stream.fromRawHandle(handle).destroy();
	}
}