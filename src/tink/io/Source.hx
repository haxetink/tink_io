package tink.io;

import haxe.io.Bytes;
import tink.io.Sink;
import tink.streams.IdealStream;
import tink.streams.Stream;

using tink.CoreApi;

@:forward(reduce)
abstract Source<E>(SourceObject<E>) from SourceObject<E> to SourceObject<E> to Stream<Chunk, E> from Stream<Chunk, E> { 
  
  #if (nodejs && !macro)
  static public inline function ofNodeStream(name, r:js.node.stream.Readable.IReadable, ?chunkSize = 0x10000):RealSource
    return tink.io.nodejs.NodejsSource.wrap(name, r, chunkSize);
  #end
  
  @:from static public function ofError(e:Error):RealSource
    return (e : Stream<Chunk, Error>);

  @:from static function ofPromised(p:Promise<RealSource>):RealSource
    return Stream.flatten(p.map(function (o) return switch o {
      case Success(s): s;
      case Failure(e): ofError(e);
    }));
  
  static public function concatAll<E>(s:Stream<Chunk, E>)
    return s.reduce(Chunk.EMPTY, function (res:Chunk, cur:Chunk) return Progress(res & cur));

  public function pipeTo<EOut, Result>(target:SinkYielding<EOut, Result>, ?options):Future<PipeResult<E, EOut, Result>> 
    return target.consume(this, options);
  
  public inline function append(that:Source<E>):Source<E> 
    return this.append(that);
    
  public inline function prepend(that:Source<E>):Source<E> 
    return this.prepend(that);
    
  @:from static inline function ofChunk<E>(chunk:Chunk):Source<E>
    return new Single(chunk);
    
  @:from static inline function ofString<E>(s:String):Source<E>
    return ofChunk(s);
    
  @:from static inline function ofBytes<E>(b:Bytes):Source<E>
    return ofChunk(b);
    
}

typedef SourceObject<E> = StreamObject<Chunk, E>;//TODO: make this an actual subtype to add functionality on

typedef RealSource = Source<Error>;

class RealSourceTools {
  static public function all(s:RealSource):Promise<Chunk>
    return Source.concatAll(s).map(function (o) return switch o {
      case Reduced(c): Success(c);
      case Failed(e): Failure(e);
    });
}

typedef IdealSource = Source<Noise>;

class IdealSourceTools {
  static public function all(s:IdealSource):Future<Chunk>
    return Source.concatAll(s).map(function (o) return switch o {
      case Reduced(c): c;
    });
}