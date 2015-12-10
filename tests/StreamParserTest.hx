package;

import haxe.io.*;
import haxe.Timer;
import haxe.unit.TestCase;
import tink.io.*;
import tink.io.StreamParser;

using tink.CoreApi;

class StreamParserTest extends TestCase {
  function testSingleSteps() {
    var source:Source = 'hello  world\t \r!!!';
    source.parse(new UntilSpace()).handle(function (x) {
      var x = x.sure();
      assertEquals('hello', x.data);
      //trace(x.rest);
      x.rest.parse(new UntilSpace()).handle(function (y) x = y.sure());
      assertEquals('world', x.data);
      x.rest.parse(new UntilSpace()).handle(function (y) x = y.sure());
      assertEquals('!!!', x.data);
    });
  }
  
  function testSplit() {
    var str = 'hello !!! world !!!!! !!! !!';
    var source:Source = str,
        a = [];
    source.parseWhile(new Splitter(Bytes.ofString('!!!')), function (x) return Future.sync(a.push(x.toString()) > 0)).handle(function (x) {
      assertTrue(x.isSuccess());
      assertEquals('hello , world ,!! , !!', a.join(','));
    });
  }
  
  function testSingleSplit() {
    var c = chunk();
    var delim = '---12345-67890---';
    var s = '$c$delim$c$delim$c';
    
    var parts = switch (s : Source).split(Bytes.ofString(delim)) {
      case v: [v.first, v.then];
    }
    
    var lengths = [c.length, 2 * c.length + delim.length];
    for (p in parts) {
      var out = new BytesOutput();
      p.pipeTo(Sink.ofOutput('membuf', out, Worker.EAGER)).handle(function (x) {
        assertEquals(lengths.shift(), out.getBytes().length);
      });
    }
    assertEquals(0, lengths.length);
  }
  function chunk() {
    var str = 'werlfkmwerf';
    
    for (i in 0...16)
      str += str;
      
    return str;
  }
  function testSplitSpeed() {
    var chunk = chunk(),
        delim = '-123456789-';
    
    var str = chunk + delim;
    
    for (i in 0...3)
      str += str;
      
    str += chunk;
    var start = Timer.stamp();
    str.split(delim);
    var direct = Timer.stamp() - start;
    var start = Timer.stamp();
    (str : Source).parseWhile(new Splitter(Bytes.ofString(delim)), function (x) { 
      assertEquals(chunk.length, x.length);
      return Future.sync(true); 
    }).handle(function (x) {
      assertTrue(x.isSuccess());
      
      var faster = Timer.stamp() - start < 100 * direct;
      if (!faster)
        trace([Timer.stamp() - start, direct]);
      assertTrue(faster);
    });
    
    str = '$delim$str$delim';
    var start = Timer.stamp();
    (str : Source).parseWhile(new Splitter(Bytes.ofString(chunk)), function (x) {
      assertEquals(delim.length, x.length);
      return Future.sync(true);
    }).handle(function (x) {
      assertTrue(x.isSuccess());      
      var faster = Timer.stamp() - start < 100 * direct;
      if (!faster)
        trace([Timer.stamp() - start, direct]);
      assertTrue(faster);
    });
  }
  
  function testParseWhile() {
    var str = 'hello world !!! how are you ??? ignore all this';
    
    var source:Source = str,
        a = [];
    source.parseWhile(new UntilSpace(), function (x) return Future.sync(a.push(x) < 7)).handle(function (x) {
      assertTrue(x.isSuccess());
      assertEquals('hello world !!! how are you ???', a.join(' '));
    });
    
  }
  
  function testStreaming() {
    var str = 'hello world !!! how are you ??? ignore all this';
    
    var source:Source = str;
    source.parseStream(new UntilSpace()).fold('', function (a, b) return '$b-$a').handle(function (x) {
      assertEquals(' $str'.split(' ').join('-'), x.sure());
    });
  }
}

private class UntilSpace extends ByteWiseParser<String> {
  
  var buf:StringBuf;
  
  public function new() {
    super();
    this.buf = new StringBuf();
  }
  
  override function read(c:Int):ParseStep<String> {
    return
      switch c {
        case white if (white <= ' '.code):
          var ret = buf.toString();
          if (ret == '')
            Progressed;
          else {
            buf = new StringBuf();
            Done(ret);
          }
        default:
          buf.addChar(c);
          Progressed;
      }
  }
}