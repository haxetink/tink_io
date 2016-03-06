package tink.io.nodejs;

import haxe.io.Bytes;
import tink.io.Source;
import tink.io.Pipe;

using tink.CoreApi;

class NodejsSource extends SourceBase {
  
  var target:js.node.stream.Readable.IReadable;
  var name:String;
  var end:Surprise<Progress, Error>;
  
  var rest:Bytes;
  var pos:Int;
  
  public function new(target, name) {
    
    this.target = target;
    this.name = name;
    
    end = Future.async(function (cb) {
      target.once('end', function () cb(Success(Progress.EOF)));
      target.once('error', function (e) cb(Failure(Error.reporter('Error while reading from $name')(e))));
    });
    
  }
  
  function readBytes(into:Bytes, offset:Int, length:Int) {
    
    if (length > rest.length - pos)
      length = rest.length - pos;
      
    into.blit(offset, rest, pos, length);
    
    pos += length;
    
    if (pos == rest.length)
      rest = null;
    
    return length;
  }
  
  override public function read(into:Buffer, max = 1 << 30):Surprise<Progress, Error> {
    if (rest == null) {
      var chunk:js.node.Buffer = target.read();
      if (chunk == null)
        return end || Future.async(function (cb) 
          target.once('readable', function () cb(Noise))
        ).flatMap(function (_) return read(into, max));
        
      rest = Bytes.ofData(cast chunk);
      pos = 0;
    }
    
    return Future.sync(into.tryReadingFrom(name, this, max));
  }
  
  override public function close():Surprise<Noise, Error> 
    return Future.sync(Success(Noise));//TODO: implement
  
  override function pipeTo<Out>(dest:PipePart<Out, Sink>, ?options:{ ?end: Bool }):Future<PipeResult<Error, Out>> {
    return 
      if (Std.is(dest, NodejsSink)) {
        var dest = (cast dest : NodejsSink);
        var writable = @:privateAccess dest.target;
        
        target.pipe(writable, options );
        
        return Future.async(function (cb) {
          @:privateAccess dest.next({
            unpipe: function (s) if (s == target) cb(AllWritten),
          });
        });
      }
      else super.pipeTo(dest);
  }  
}
