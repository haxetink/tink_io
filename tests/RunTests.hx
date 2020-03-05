package;

import tink.unit.*;
import tink.testrunner.*;

using tink.CoreApi;

class RunTests {
  
  static function main() {
    Runner.run(TestBatch.make([
      #if (sys || nodejs) new PipeTest(),#end
      new SourceTest(),
      new ParserTest(),
      new PassThroughTest(),
      #if (js && !nodejs) new JsTest(), #end
    ])).handle(Runner.exit);
    
    
    #if (java && jvm)
    // FIXME: this prevents the tests from exiting early, to be investigated
    haxe.Timer.delay(function() trace('End'), 20000);
    #end
  }
  
}