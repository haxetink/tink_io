package tink.io;

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
  
  public function pipeTo<EOut>(target:Sink<EOut>, ?options):Future<PipeResult<E, EOut>> 
    return target.consume(this, options);
  
}

typedef SourceObject<E> = StreamObject<Chunk, E>;