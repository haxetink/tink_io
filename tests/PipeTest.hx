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
      for (i in 0...20)
        s += s;

      s+='123456789';
      fsrc.saveContent(s);
    }
    
    var src = readFile(fsrc, 5249710),
        dst = writeFile(fdst);

    var start = haxe.Timer.stamp();
    src.pipeTo(dst, {end: true}).handle(function(o) {
        trace(haxe.Timer.stamp() - start);
        asserts.assert(o == AllWritten);
        asserts.assert(fsrc.getContent().length == fdst.getContent().length);
        asserts.done();
    });
    
    return asserts;
  }

  function readFile(name:String, ?chunkSize) {
    return
      #if nodejs
        Source.ofNodeStream(
          'Input from file $name', 
          js.node.Fs.createReadStream(name), 
          { chunkSize: chunkSize }
        );
      #elseif sys
        Source.ofInput(
          'Input from file $name', 
          sys.io.File.read(name, true), 
          { chunkSize: chunkSize }
        );
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
      asserts.assert(dst.getContent().length == 0);
      asserts.done();
    });
    
    return asserts;
  }
  
}