package tink.io;

import haxe.io.Bytes;
import tink.io.Sink;
import tink.io.StreamParser;
import tink.streams.IdealStream;
import tink.streams.RealStream;
import tink.streams.Stream;

using tink.io.Source;
using tink.CoreApi;

@:forward(reduce)
abstract Source<E>(SourceObject<E>) from SourceObject<E> to SourceObject<E> to Stream<Chunk, E> from Stream<Chunk, E> { 
  

  public static var EMPTY(default, null):IdealSource = Empty.make();
  
  public var depleted(get, never):Bool;
    inline function get_depleted() return this.depleted;

  #if (nodejs && !macro)
  static public inline function ofNodeStream(name, r:js.node.stream.Readable.IReadable, ?options:{ ?chunkSize: Int, ?onEnd:Void->Void }):RealSource {
    if (options == null) 
      options = {};
    return tink.io.nodejs.NodejsSource.wrap(name, r, options.chunkSize, options.onEnd);
  }
  #end
  
  public function chunked():Stream<Chunk, E>
    return this;
  
  @:from static public function ofError(e:Error):RealSource
    return (e : Stream<Chunk, Error>);

  @:from static function ofFuture(f:Future<IdealSource>):IdealSource
    return Stream.flatten((cast f:Future<Stream<Chunk, Noise>>)); // TODO: I don't understand why this needs a cast
    
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
    
  public function skip(len:Int):Source<E> {
    return this.regroup(function(chunks:Array<Chunk>) {
      var chunk = chunks[0];
      if(len <= 0) return Converted(Stream.single(chunk));
      var length = chunk.length;
      var out = Converted(if(len < length) Stream.single(chunk.slice(len, length)) else Empty.make());
      len -= length;
      return out;
    });
  }
    
  public function limit(len:Int):Source<E> {
    return this.regroup(function(chunks:Array<Chunk>) {
      if(len <= 0) return Converted(Empty.make());
      var chunk = chunks[0];
      var length = chunk.length;
      var out = Converted(Stream.single(if(len < length) chunk.slice(0, len) else chunk));
      len -= length;
      return out;
    });
  }
    
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

  static public function parse<R>(s:RealSource, p:StreamParser<R>):Promise<Pair<R, RealSource>>
    return StreamParser.parse(s, p).map(function (r) return switch r {
      case Parsed(data, rest): Success(new Pair(data, rest));
      case Invalid(e, _) | Broke(e): Failure(e);
    });
    
  static public function split(src:RealSource, delim:Chunk):SplitResult<Error> {
    var s = parse(src, new Splitter(delim));
    // TODO: make all these lazy
    return {
      before: Stream.promise(s.next(function(p):RealSource return switch p.a {
        case Some(chunk): chunk;
        case None: src;
      })),
      delimiter: s.next(function(p) return switch p.a {
        case Some(_): delim;
        case None: new Error(NotFound, 'Delimiter not found');
      }),
      after: Stream.promise(s.next(function(p):RealSource return p.b)),
    }
  }
    
  static public function idealize(s:RealSource, rescue:Error->Void):IdealSource
    return (s.chunked().idealize(function(e) {rescue(e); return cast Source.EMPTY;}):StreamObject<Chunk, Noise>);
}

typedef IdealSource = Source<Noise>;
typedef SplitResult<E> = {
  before:Source<E>,
  delimiter:Promise<Chunk>,
  after:Source<E>,
}

class IdealSourceTools {
  static public function all(s:IdealSource):Future<Chunk>
    return Source.concatAll(s).map(function (o) return switch o {
      case Reduced(c): c;
    });
    
  static public function parse<R>(s:IdealSource, p:StreamParser<R>):Promise<Pair<R, IdealSource>>
    return StreamParser.parse(s, p).map(function (r) return switch r {
      case Parsed(data, rest): Success(new Pair(data, rest));
      case Invalid(e, _): Failure(e);
    });
    
  static public function parseStream<R>(s:IdealSource, p:StreamParser<R>):RealStream<R>
    return StreamParser.parseStream(s, p);
    
  static public function split(s:IdealSource, delim:Chunk):SplitResult<Noise> {
    var s = RealSourceTools.split((cast s:RealSource), delim);
    // TODO: make all these lazy
    return {
      before: s.before.idealize(function(e) {}),
      delimiter: s.delimiter,
      after: s.after.idealize(function(e) {}),
    }
  }
}