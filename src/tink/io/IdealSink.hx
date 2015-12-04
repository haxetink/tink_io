package tink.io;

import tink.core.Future;
import tink.io.Buffer;
import tink.io.IdealSink;
import tink.io.Sink;

using tink.CoreApi;

@:forward
abstract IdealSink(IdealSinkObject) from IdealSinkObject to IdealSinkObject to Sink {
  
}

interface IdealSinkObject extends SinkObject {
  function writeSafely(from:Buffer):Future<Progress>;
  function closeSafely():Future<Noise>;
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