package tink.io.java;

import haxe.io.Bytes;
import tink.io.Source.SourceBase;
import tink.io.Worker;

using tink.CoreApi;

@:noCompletion
class JavaSource extends SourceBase {
  var target:java.nio.channels.ReadableByteChannel;
  var name:String;
  var worker:Worker;
  
  public function new(target, name, ?worker:Worker) {
    this.target = target;
    this.name = name;
    this.worker = worker.ensure();
  }
  
  function readBytes(into:Bytes, pos:Int, len:Int):Int 
    return target.read(java.nio.ByteBuffer.wrap(into.getData(), pos, len));
  
  override public function read(into:Buffer, max = 1 << 30):Surprise<Progress, Error>
    return worker.work(function () return into.tryReadingFrom(name, this, max));
    
  override public function close():Surprise<Noise, Error> {
    target.close();
    return Future.sync(Success(Noise));
  }
  
  override public function parseWhile<T>(parser:StreamParser<T>, cond:T->Future<Bool>):Surprise<Source, Error> {
    var buf = Buffer.alloc(Buffer.sufficientWidthFor(parser.minSize()));
    var ret = Future.async(function (cb) {
      function step(?noread)
        worker.work(function () return
          switch if (noread) Success(Progress.NONE) else buf.tryReadingFrom(name, this) {
            case Success(v):
              if (v.isEof)
                buf.seal();
              
              var available = buf.available;
              switch parser.progress(buf) {
                case Success(None) if (v.isEof && available == buf.available):
                  Failure(new Error('Parser hung on input'));
                case v: v;
              }
            case Failure(e):
              Failure(e);
          }
        ).handle(function (o) switch o {
          case Failure(e): cb(Failure(e));
          case Success(Some(v)):
            cond(v).handle(function (v) 
              if (v) step(true);
              else cb(Success(this.prepend(buf.content())))
            );
          case Success(None): step();
        });
        
      step();
    });
    ret.handle(@:privateAccess buf.dispose);
    
    return ret;
  }    
  
  //TODO: overwrite pipe for maximum fancyness
}