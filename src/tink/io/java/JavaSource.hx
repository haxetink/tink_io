package tink.io.java;

import haxe.io.Bytes;
import tink.io.Source.SourceBase;
import tink.io.Worker;

using tink.CoreApi;

@:noCompletion
class JavaSource extends SourceBase {
  var target:java.nio.channels.ReadableByteChannel;
  var name:String;
  var worker:Worker;
  
  public function new(target, name, ?worker:Worker) {
    this.target = target;
    this.name = name;
    this.worker = worker.ensure();
  }
  
  function readBytes(into:Bytes, pos:Int, len:Int):Int 
    return target.read(java.nio.ByteBuffer.wrap(into.getData(), pos, len));
  
  override public function read(into:Buffer, max = 1 << 30):Surprise<Progress, Error>
    return worker.work(function () return into.tryReadingFrom(name, this, max));
    
  override public function close():Surprise<Noise, Error> {
    target.close();
    return Future.sync(Success(Noise));
  }
  
  //TODO: overwrite pipe for maximum fancyness
}