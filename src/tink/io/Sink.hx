package tink.io;

import tink.Chunk;
import tink.io.PipeOptions;
import tink.streams.Stream;

using tink.io.Source;
using tink.CoreApi;

typedef Sink<FailingWith> = SinkYielding<FailingWith, Noise>;
typedef RealSink = Sink<Error>;
typedef IdealSink = Sink<Noise>;

@:forward
abstract SinkYielding<FailingWith, Result>(SinkObject<FailingWith, Result>) 
  from SinkObject<FailingWith, Result> 
  to SinkObject<FailingWith, Result> {
    
  public static var BLACKHOLE(default, null):IdealSink = Blackhole.inst;

  public function end():Promise<Bool>
    return
      if (this.sealed) false;
      else this.consume(Source.EMPTY, { end: true }).map(function (r) return switch r {
        case AllWritten | SinkEnded(_): Success(true);
        case SinkFailed(e, _): Failure(e);
      });
      
  @:to function dirty():Sink<Error>
    return cast this;
    
  @:from static function ofError(e:Error):RealSink
    return new ErrorSink(e);

  @:from static function ofPromised(p:Promise<RealSink>):RealSink
    return new FutureSink(p.map(function(o) return switch o {
      case Success(v): v;
      case Failure(e): ofError(e);
    }));

  #if (nodejs && !macro)
  static public inline function ofNodeStream(name, r:js.node.stream.Writable.IWritable):RealSink
    return tink.io.nodejs.NodejsSink.wrap(name, r);
  #end
  
  #if cs
  static public inline function ofCsStream(name, r:cs.system.io.Stream):RealSink
    return tink.io.cs.CsSink.wrap(name, r);
  #end

  static public function ofOutput(name:String, target:haxe.io.Output, ?options:{ ?worker:Worker }):RealSink
    return new tink.io.std.OutputSink(name, target, switch options {
      case null | { worker: null }: Worker.get();
      case { worker: w }: w;
    });


}

private class Blackhole extends SinkBase<Noise, Noise> {
  public static var inst(default, null):Blackhole = new Blackhole();
  
  function new() {}

  override public function consume<EIn>(source:Stream<Chunk, EIn>, options:PipeOptions):Future<PipeResult<EIn, Noise, Noise>>
    return source.forEach(function(_) return Resume).map(function(o):PipeResult<EIn, Noise, Noise> return switch o {
      case Depleted: AllWritten;
      case Halted(_): throw 'unreachable';
      case Failed(e): SourceFailed(e);
    });
}

private class FutureSink<FailingWith, Result> extends SinkBase<FailingWith, Result> {
  var f:Future<SinkYielding<FailingWith, Result>>;
  public function new(f)
    this.f = f;

  override public function consume<EIn>(source:Stream<Chunk, EIn>, options:PipeOptions):Future<PipeResult<EIn, FailingWith, Result>>
    return f.flatMap(function (sink) return sink.consume(source, options));
}

private class ErrorSink<Result> extends SinkBase<Error, Result> {
  
  var error:Error;

  public function new(error)
    this.error = error;

  override function get_sealed() 
    return false;

  override public function consume<EIn>(source:Stream<Chunk, EIn>, options:PipeOptions):Future<PipeResult<EIn, Error, Result>>
    return Future.sync(cast PipeResult.SinkFailed(error, source));//TODO: there's something rotten here - the cast should be unnecessary
}

interface SinkObject<FailingWith, Result> {
  var sealed(get, never):Bool;
  function consume<EIn>(source:Stream<Chunk, EIn>, options:PipeOptions):Future<PipeResult<EIn, FailingWith, Result>>;
  
  //function idealize(recover:Error->SinkObject<FailingWith>):IdealSink;
}

class SinkBase<FailingWith, Result> implements SinkObject<FailingWith, Result> {
  
  public var sealed(get, never):Bool;
    function get_sealed() return true;
  
  public function consume<EIn>(source:Stream<Chunk, EIn>, options:PipeOptions):Future<PipeResult<EIn, FailingWith, Result>>
    return throw 'not implemented';
    
  //public function idealize(onError:Callback<Error>):IdealSink;
    
  //public function idealize(onError:Callback<Error>):IdealSink
    //return new IdealizedSink(this, onError);
}

//
//class IdealizedSink extends IdealSinkBase {
  //var target:Sink;
  //var onError:Callback<Error>;
  //
  //public function new(target, onError) {
    //this.target = target;
    //this.onError = onError;
  //}
  //
  //override public function consumeSafely(source:IdealSource, options:PipeOptions):Future<IdealSource>
    //return Future.async(function (cb) 
      //target.consume(source, options).handle(function (c) {
        //switch c.error {
          //case Some(e): onError.invoke(e);
          //default:
        //}
        //cb(c.rest);
      //})
    //);
  //
  //override public function endSafely():Future<Bool> {
    //return target.end().recover(function (_) return Future.sync(false));
  //}
//}