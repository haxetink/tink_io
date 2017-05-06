package;

import tink.io.std.InputSource;
import tink.io.Source;
import tink.io.Sink;
import tink.io.PipeResult;

using tink.CoreApi;
using sys.io.File;
using sys.FileSystem;

@:asserts
class PipeTest {
  
  public function new() {}
  
  public function copyFile() {
    var fsrc = 'example.blob';
    var fdst = 'copy.blob';

    if(!fsrc.exists()) {
      var s = 'some random content';
      for (i in 0...16)
        s += s;
      fsrc.saveContent(s);
    }
    
    var src = readFile(fsrc),
        dst = writeFile(fdst);

    src.pipeTo(dst, {end: true}).handle(function(o) {
        asserts.assert(o == AllWritten);
        asserts.assert(fsrc.getContent() == fdst.getContent());
        asserts.done();
    });
    
    return asserts;
  }

  function readFile(name:String) {
    return
      #if nodejs
        Source.ofNodeStream('Input from file $name', js.node.Fs.createReadStream(name));
      #elseif sys
        Source.ofInput('Input from file $name', sys.io.File.read(name, true));
      #else
        #error "not implemented"
      #end 
  }

  function writeFile(name:String) {
    return
      #if nodejs
        Sink.ofNodeStream('Output to file $name', js.node.Fs.createWriteStream(name));
      #elseif sys
        Sink.ofOutput('Output to file $name', sys.io.File.write(name, true));
      #else
        #error "not implemented"
      #end
  }
  
  public function empty() {
    var dst = 'empty.blob';
    var sink = writeFile(dst);
    function _pipe(src:IdealSource) {
      return src.pipeTo(sink).map(function(x) {
        asserts.assert(x == AllWritten);
        return Noise;
      });
    }
    
    Future.ofMany([
      _pipe(''),
      _pipe(Source.EMPTY),
    ]).handle(function(_) {
      asserts.assert(dst.getBytes().length == 0);
      asserts.done();
    });
    
    return asserts;
  }
  
}