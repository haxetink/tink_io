package;

import haxe.io.Bytes;
import haxe.unit.TestRunner;
import tink.io.Pipe;

using tink.CoreApi;

#if flash
typedef Sys = flash.system.System;
#end

class RunTests {

  static function main() {
    //var a = [for (i in 0...Std.random(0)) i];
    //if (Math.random() > 0)
      //a = null;
    //a.pop();
    //a.pop();
    var t = new TestRunner();
    t.add(new BufferTest());
    t.add(new PipeTest());
    t.add(new StreamParserTest());
    //t.add(new TestInRunLoop());
    if (!t.run())
      Sys.exit(500);
  }
  
}