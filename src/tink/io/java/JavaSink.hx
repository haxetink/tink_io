package tink.io.java;

import haxe.io.Bytes;
import tink.io.Sink.SinkBase;

using tink.CoreApi;

@:noCompletion
class JavaSink extends SinkBase { 
  
  var target:java.nio.channels.WritableByteChannel;
  var name:String;
  var worker:Worker;
  
  public function new(target, name, ?worker:Worker) {
    this.target = target;
    this.name = name;
    this.worker = worker.ensure();
  }
  
  function writeBytes(into:Bytes, pos:Int, len:Int):Int 
    return target.write(java.nio.ByteBuffer.wrap(into.getData(), pos, len));
  
  override public function write(into:Buffer):Surprise<Progress, Error>
    return worker.work(function () return into.tryWritingTo(name, this));
    
  override public function close():Surprise<Noise, Error> {
    target.close();
    return Future.sync(Success(Noise));
  }

  
}