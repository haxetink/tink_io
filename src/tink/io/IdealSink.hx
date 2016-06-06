package tink.io;

import haxe.io.BytesBuffer;
import tink.core.Future;
import tink.io.Buffer;
import tink.io.IdealSink;
import tink.io.Progress;
import tink.io.Sink;

using tink.CoreApi;

@:forward
abstract IdealSink(IdealSinkObject) from IdealSinkObject to IdealSinkObject to Sink {
  static public function inMemory(whenDone:Callback<BytesBuffer>, ?buffer:BytesBuffer):IdealSink
    return new MemorySink(whenDone, buffer);
}

interface IdealSinkObject extends SinkObject {
  function writeSafely(from:Buffer):Future<Progress>;
  function closeSafely():Future<Noise>;
}

class BlackHole extends IdealSinkBase {
  
  static public var INST(default, null):IdealSink = new BlackHole();
  
  function new() {}
  
  function writeBytes(_, _, len) 
    return len;
  
  override public function writeSafely(from:Buffer):Future<Progress>
    return Future.sync(from.writeTo(this));
    
}

class IdealizedSink extends IdealSinkBase {
  
  var target:Sink;
  var onError:Callback<Error>;
  
  public function new(target, onError) {
    this.target = target;
    this.onError = onError;
  }
  
  override public function writeSafely(from:Buffer):Future<Progress>
    return target.write(from).map(function (o) return switch o {
      case Success(p): p;
      case Failure(e):
        onError.invoke(e);
        from.clear();
        Progress.EOF;
    });
    
  override public function closeSafely():Future<Noise>
    return target.close().map(function (o) {
      switch o {
        case Failure(e): onError.invoke(e);
        default:
      }
      return Noise;
    });
}

class IdealSinkBase extends SinkBase implements IdealSinkObject {
  
  override public function idealize(onError:Callback<Error>):IdealSink
    return this;
  
  public function writeSafely(from:Buffer):Future<Progress>
    return throw 'not implemented';
    
  public function closeSafely():Future<Noise>
    return Future.sync(Noise);
    
  override public function write(from:Buffer):Surprise<Progress, Error> 
    return writeSafely(from).map(Success);
  
  override public function close():Surprise<Noise, Error>
    return closeSafely().map(Success);
}

private class MemorySink extends IdealSinkBase {
  var whenDone:Callback<BytesBuffer>;
  var buffer:BytesBuffer;
  public function new(whenDone, buffer) {
    this.whenDone = whenDone;
    this.buffer = switch buffer {
      case null: new BytesBuffer();
      case v: v;
    }
  }
  
  function writeBytes(b, pos, len) {
    buffer.addBytes(b, pos, len);
    return len;
  }
  
  override public function writeSafely(from:Buffer):Future<Progress> 
    return 
      Future.sync(
        if (this.buffer == null) Progress.EOF
        else from.writeTo(this)
      );
  
  override public function closeSafely():Future<Noise> {
    if (buffer != null) {
      whenDone.invoke(buffer);
      buffer = null;
      whenDone = null;
    }
    return super.closeSafely();
  }
    
}