package;

import tink.io.Source;
import tink.io.Sink;
import tink.io.PipeResult;

using sys.io.File;
using sys.FileSystem;

@:asserts
class TestPipe {
  
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
}