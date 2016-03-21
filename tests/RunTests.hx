package;

import haxe.io.Bytes;
import haxe.unit.TestRunner;
import tink.io.Pipe;

using tink.CoreApi;

class RunTests {

  static function main() {
    var t = new TestRunner();
    //t.add(new BufferTest());
    //t.add(new PipeTest());
    t.add(new StreamParserTest());
    //t.add(new TestInRunLoop());
    t.run();
  }
  
}