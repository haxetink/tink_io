package;

import tink.unit.*;
import tink.testrunner.*;

class RunTests {
  
  static function main() {
    #if (java && jvm)
    // Touch EntryPoint on the real main thread before any JDK pool thread
    // (e.g. an AsynchronousSocketChannel/AsynchronousFileChannel completion)
    // can trigger its static init and wrongly capture a pool thread as
    // "main" (which has no event loop, causing "Event loop is not available").
    haxe.EntryPoint.runInMainThread(function() {});
    #end

    Runner.run(TestBatch.make([
      #if (sys || nodejs) new PipeTest(),#end
      new SourceTest(),
      new ParserTest(),
      new CastTest(),
      #if (js && !nodejs) new JsTest(), #end
    ])).handle(Runner.exit);
  }
  
}