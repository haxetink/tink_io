package;

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
    if(!fsrc.exists()) fsrc.saveContent('some random content');
    
    #if nodejs
    var src = Source.ofNodeStream('src', js.node.Fs.createReadStream(fsrc), {chunkSize: 0x10000});
    var dst = Sink.ofNodeStream('dst', js.node.Fs.createWriteStream(fdst));
    #else
      #error "not implemented"
    #end
    
    src.pipeTo(dst, {end: true}).handle(function(o) {
        asserts.assert(o == AllWritten);
        asserts.assert(fsrc.getContent() == fdst.getContent());
        asserts.done();
    });
    
    return asserts;
  }
  
  public function empty() {
    var dst = 'empty.blob';
    var sink = Sink.ofNodeStream(dst, js.node.Fs.createWriteStream(dst));
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