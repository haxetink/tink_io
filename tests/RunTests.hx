package;

import tink.unit.*;
import tink.testrunner.*;

using tink.CoreApi;

class RunTests {
  
  static function main() {
    Runner.run(TestBatch.make([
      #if sys new PipeTest(),#end
      new SourceTest(),
      new ParserTest(),
      new PassThroughTest(),
      #if (js && !nodejs) new JsTest(), #end
    ])).handle(Runner.exit);
  }
  
}