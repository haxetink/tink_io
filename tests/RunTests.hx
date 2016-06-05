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
    #if flash
    haxe.Log.trace = function(v, ?pos) flash.Lib.trace(v);
    #end
    var t = new TestRunner();
    t.add(new BufferTest());
    t.add(new PipeTest());
    t.add(new StreamParserTest());
    //t.add(new TestInRunLoop());
    Sys.exit(
      if (t.run()) 0
      else 500
    );
  }
  
}