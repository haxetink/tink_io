package;

import haxe.io.Bytes;
import haxe.unit.TestRunner;
import tink.http.Request;
import tink.http.Response;
import tink.io.Source;

using tink.CoreApi;

class RunTests {

  static function main() {
    var t = new TestRunner();
    t.add(new BufferTest());
    t.add(new PipeTest());
    t.run();
    //var map = [];
    //trace([Foo  3, Bar => 7]);
  }
  
}

@:enum abstract Test(String) to String {
  
  var Foo = 'foo';
  var Bar = 'bar';
  
  @:op(a => b) static function set(a:Test, b:Int) return b;
}