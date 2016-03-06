package tink.io.cs;

import haxe.io.Bytes;
import tink.io.Buffer;
import tink.io.Sink;

using tink.CoreApi;

class CsSink extends SinkBase {
  
  var target:cs.system.io.Stream;
  var name:String;
  var worker:Worker;
  
  public function new(target, name, ?worker:Worker) {
    this.target = target;
    this.name = name;
    this.worker = worker.ensure();
  }
  
  function writeBytes(from:Bytes, start:Int, length:Int) {
    return target.Write(into.getData(), start, length);
  }
  
  override public function write(from:Buffer, max = 1 << 30):Surprise<Progress, Error> {
    return worker.work(function () return into.tryWritingTo(name, this, max));
  }
  
  override public function close():Surprise<Noise, Error> {
    target.Close();
    return Future.sync(Success(Noise));
  }
  
}