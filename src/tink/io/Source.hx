package tink.io;

import haxe.io.Bytes;
import tink.io.Sink;
import tink.streams.IdealStream;
import tink.streams.Stream;

using tink.CoreApi;

@:forward(append, prepend)
abstract Source<E>(SourceObject<E>) from SourceObject<E> to SourceObject<E> to Stream<Chunk, E> from Stream<Chunk, E> { 
  
  #if (nodejs && !macro)
  static public inline function ofNodeStream(name, r:js.node.stream.Readable.IReadable, ?chunkSize = 0x10000):RealSource
    return tink.io.nodejs.NodejsSource.wrap(name, r, chunkSize);
  #end
  
  @:from static public function ofError(e:Error):RealSource
    return (e : Stream<Chunk, Error>);
  
  public function pipeTo<EOut, Result>(target:SinkYielding<EOut, Result>, ?options):Future<PipeResult<E, EOut, Result>> 
    return target.consume(this, options);
  
  public inline function append(that:Source<E>) 
    return this.append(that);
    
  public inline function prepend(that:Source<E>) 
    return this.prepend(that);
    
  @:from static inline function ofChunk<E>(chunk:Chunk):Source<E>
    return new Single(chunk);
    
  @:from static inline function ofString<E>(s:String):Source<E>
    return ofChunk(s);
    
  @:from static inline function ofBytes<E>(b:Bytes):Source<E>
    return ofBytes(b);
    
}

typedef SourceObject<E> = StreamObject<Chunk, E>;

//class BufferedSource<E> extends StreamBase<Chunk, E> {
  //
  //var target:Source<E>;
  //var highWaterMark:Int;
  //
  //public function new(target, highWaterMark) {
    //this.target = target;
    //this.highWaterMark = highWaterMark;
  //}
  //
  //override function forEach<Safety>(handler:Handler<Chunk, Safety>):Future<Conclusion<Chunk, Safety, E>> {
    //
    //var buffered = Chunk.EMPTY,
        //busy = false;
    //
    //return (target:Stream<Chunk, E>).forEach(function (chunk):Future<Handled<Safety>> {
      //return 
        //if (busy) {
          //if (buffered.length < highWaterMark) {
            //Future.sync(Resume);
          //}
        //}
        //else {
          //busy = true;
          //handler.apply(chunk).handle(function (h) switch h {
            //case BackOff:
            //case Finish:
            //case Resume:
              //
            //case Fail(e):
          //});
          //Future.sync(Resume);
        //}
    //});
  //}
//
//}