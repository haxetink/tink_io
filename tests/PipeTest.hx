package;
import tink.io.Sink;

import haxe.io.Bytes;
import haxe.io.BytesBuffer;
import haxe.unit.TestCase;
import tink.io.Buffer;
import tink.io.Sink.SinkObject;
import tink.io.Source;
import tink.io.Pipe;
import tink.io.Progress;

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
      
      Pipe.make(new FakeSource(Bytes.ofString(s)), out, Bytes.alloc(511)).handle(
        function (o) switch o {
          case { bytesWritten: b, status: AllWritten } :
            assertEquals(s.length, b); 
            assertEquals(s, out.getData().toString());
          default:
        }
      );
      
    }
  }
}


class FakeSink implements SinkObject {
  var out:BytesBuffer;
  public function new() {
    this.out = new BytesBuffer();
  }
	public function write(from:Buffer):Surprise<Progress, Error> {
    return Future.sync(from.tryWritingTo('fake sink', this));
  }
  public function writeBytes(bytes:Bytes, pos:Int, len:Int):Int {
    len = randomize(len);
    this.out.addBytes(bytes, pos, len);
    
    return len;
  }
  
  public function getData()
    return this.out.getBytes();
  
	public function close() 
    return Future.sync(Success(Noise));
 
  static public function randomize(len:Int) {
    if (len > 8) {
      len >>= 1;
      len += Std.random(len);
    }
    return len;
  }
}
class FakeSource implements SourceObject {
  var data:Bytes;
  var pos = 0;
  var error:Dynamic;
  
  public function new(data, ?error) {
    this.data = data;
    this.error = error;
  }
  
  public function append(other:Source):Source 
    return CompoundSource.of(this, other);
  
  public function read(into:Buffer):Surprise<Progress, Error> 
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
  
  public function close()
    return Future.sync(Success(Noise));
  
}