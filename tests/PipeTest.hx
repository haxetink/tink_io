package;

import haxe.unit.TestCase;
import tink.io.*;
import haxe.io.*;
import tink.io.Sink;
import tink.io.Source;
import tink.io.Pipe;

using tink.CoreApi;

class PipeTest extends TestCase {
  function testSimple() {      
    for (len in [0, 1, 5, 17, 257, 65537]) {
      var chars = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz';
      var buf = new StringBuf();
      for (i in 0...len)
        buf.addChar(chars.charCodeAt(Std.random(chars.length)));
      var s = buf.toString();
      var out = new FakeSink();
      
      function noError(e) {
        assertEquals(null, e);
      }
      
      Pipe.make(new FakeSource(Bytes.ofString(s)).idealize(noError), out.idealize(noError), Buffer.unmanaged(Bytes.alloc(511))).handle(
        function (o) switch o {
          case AllWritten:
            assertEquals(s, out.getData().toString());
        }
      );
      
      
      
    }
  }
}


class FakeSink extends SinkBase {
  var out:BytesBuffer;
  public function new() {
    this.out = new BytesBuffer();
  }
	override public function write(from:Buffer):Surprise<Progress, Error> {
    return Future.sync(from.tryWritingTo('fake sink', this));
  }
  public function writeBytes(bytes:Bytes, pos:Int, len:Int):Int {
    len = randomize(len);
    this.out.addBytes(bytes, pos, len);
    
    return len;
  }
  
  public function getData()
    return this.out.getBytes();
 
  static public function randomize(len:Int) {
    if (len > 8) {
      len >>= 1;
      len += Std.random(len);
    }
    return len;
  }
}

class FakeSource extends SourceBase {
  var data:Bytes;
  var pos = 0;
  var error:Dynamic;
    
  public function new(data, ?error) {
    this.data = data;
    this.error = error;
  }  
  
  override public function read(into:Buffer):Surprise<Progress, Error> 
    return Future.sync(into.tryReadingFrom('fake source', this));
  
  public function readBytes(bytes:Bytes, offset:Int, len:Int):Int {
    len = FakeSink.randomize(len);
    if (pos == data.length) 
      if (error != null) 
        throw error;
      else
        return -1;
    
    if (len > data.length - pos) 
      len = data.length - pos;
    
    bytes.blit(offset, data, pos, len);
    pos += len;
    return len;  
  }
  
  override public function close()
    return Future.sync(Success(Noise));
  
}