package;

import tink.unit.*;
import tink.testrunner.*;

class RunTests {
  
  static function main() {
    Runner.run(TestBatch.make([
      #if sys new PipeTest(),#end
      new SourceTest(),
      new ParserTest(),
    ])).handle(Runner.exit);
  }
  
}