package tink.io.cs;

import haxe.io.Bytes;
import tink.io.Buffer;
import tink.io.Source;

using tink.CoreApi;

class CsSource extends SourceBase {
  var target:cs.system.io.Stream;
  var name:String;
  var worker:Worker;
  public function new(target, name, ?worker:Worker) {
    this.target = target;
    this.name = name;
    this.worker = worker.ensure();
  }
  
  function readBytes(into:Bytes, start:Int, length:Int) {
    return target.Read(into.getData(), start, length);
  }
  
  override public function read(into:Buffer, max = 1 << 30):Surprise<Progress, Error> {
    return worker.work(function () return into.tryReadingFrom(name, this, max));
  }
  
  override public function close():Surprise<Noise, Error> {
    target.Close();
    return Future.sync(Success(Noise));
  }
  
}