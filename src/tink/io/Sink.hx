package tink.io;

import tink.io.IdealSink;
import tink.io.IdealSource;
import tink.streams.Stream;

using tink.CoreApi;

typedef RealSink = Sink<Error>;

@:forward
abstract Sink<E>(SinkObject<E>) from SinkObject<E> to SinkObject<E> {
  
  #if (nodejs && !macro)
  static public function ofNodeStream(name, r:js.node.stream.Writable.IWritable):RealSink
    return tink.io.nodejs.NodejsSink.wrap(name, r);
  #end

}

interface SinkObject<E> {
  //var sealed(get, never):Bool;
  function consume<EIn>(source:Stream<Chunk, EIn>, options:PipeOptions):Future<PipeResult<EIn, E>>;
  //function idealize(recover:Error->SinkObject<E>):IdealSink;
}

class SinkBase<E> implements SinkObject<E> {
  
  public function consume<EIn>(source:Stream<Chunk, EIn>, options:PipeOptions):Future<PipeResult<EIn, E>>
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