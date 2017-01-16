package tink.io;

import tink.Chunk;
import tink.io.IdealSink;
import tink.io.IdealSource;
import tink.io.PipeOptions;
import tink.streams.Stream;

using tink.CoreApi;

typedef RealSink = Sink<Error>;

typedef Sink<FailingWith> = SinkYielding<FailingWith, Noise>;

@:forward
abstract SinkYielding<FailingWith, Result>(SinkObject<FailingWith, Result>) 
  from SinkObject<FailingWith, Result> 
  to SinkObject<FailingWith, Result> {
  
  #if (nodejs && !macro)
  static public function ofNodeStream(name, r:js.node.stream.Writable.IWritable):RealSink
    return tink.io.nodejs.NodejsSink.wrap(name, r);
  #end

}

interface SinkObject<FailingWith, Result> {
  var sealed(get, never):Bool;
  function consume<EIn>(source:Stream<Chunk, EIn>, options:PipeOptions):Future<PipeResult<EIn, FailingWith, Result>>;
  
  //function idealize(recover:Error->SinkObject<FailingWith>):IdealSink;
}

class SinkBase<FailingWith, Result> implements SinkObject<FailingWith, Result> {
  
  public var sealed(get, never):Bool
    function get_sealed() return true
  
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