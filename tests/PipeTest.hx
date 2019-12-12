package;

import tink.io.std.InputSource;
import tink.io.Source;
import tink.io.Sink;
import tink.io.PipeResult;

using tink.CoreApi;
using sys.io.File;
using sys.FileSystem;

@:asserts
@:timeout(15000)
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
    #if nodejs
     return
        Source.ofNodeStream(
          'Input from file $name', 
          js.node.Fs.createReadStream(name), 
          { chunkSize: chunkSize }
        );
    #elseif cs
      return
        Source.ofCsStream(
          'Input from file $name', 
          new cs.system.io.FileStream(
            name,
            cs.system.io.FileMode.Open,
            cs.system.io.FileAccess.Read,
            cs.system.io.FileShare.ReadWrite
          ),
          { chunkSize: chunkSize }
        );
    #elseif java
      var path = java.nio.file.Paths.get(name, new java.NativeArray(0));
      var op:java.NativeArray<java.nio.file.OpenOption> = java.NativeArray.make(cast java.nio.file.StandardOpenOption.READ);
      return
        Source.ofJavaFileChannel(
          'Input from file $name',
          java.nio.channels.AsynchronousFileChannel.open(path, op),
          { chunkSize: chunkSize }
        );
    #elseif sys
      return
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
    #if nodejs
      return
        Sink.ofNodeStream('Output to file $name', js.node.Fs.createWriteStream(name));
    #elseif cs
      return
        Sink.ofCsStream('Output to file $name', new cs.system.io.FileStream(
          name,
          cs.system.io.FileMode.OpenOrCreate,
          cs.system.io.FileAccess.Write,
          cs.system.io.FileShare.ReadWrite
      ));
    #elseif java
      var path = java.nio.file.Paths.get(name, new java.NativeArray(0));
      var op:java.NativeArray<java.nio.file.OpenOption> = java.NativeArray.make(cast java.nio.file.StandardOpenOption.CREATE, cast java.nio.file.StandardOpenOption.WRITE);
      return
        Sink.ofJavaFileChannel('Output to file $name', java.nio.channels.AsynchronousFileChannel.open(path, op));
    #elseif sys
      return
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