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
  
  @:to inline function dirty():Source<Error>
    return cast this;
  
  public var depleted(get, never):Bool;
    inline function get_depleted() return this.depleted;

  #if (nodejs && !macro)
  @:noUsing static public inline function ofNodeStream(name:String, r:js.node.stream.Readable.IReadable, ?options:{ ?chunkSize: Int, ?onEnd:Void->Void }):RealSource {
    if (options == null) 
      options = {};
    return tink.io.nodejs.NodejsSource.wrap(name, r, options.chunkSize, options.onEnd);
  }
  
  public function toNodeStream():js.node.stream.Readable.IReadable {
    var native = @:privateAccess new js.node.stream.PassThrough(); // https://github.com/HaxeFoundation/hxnodejs/pull/91
    
    var source = chunked();
    function write() {
      source.forEach(function(chunk:Chunk) {
        var ok = native.write(js.node.Buffer.hxFromBytes(chunk.toBytes()));
        return ok ? Resume : Finish;
      }).handle(function(o) switch o {
        case Depleted:
          native.end();
        case Halted(rest):
          source = rest;
          native.once('drain', write);
        case Failed(e):
          native.emit('error', new js.Error(e.message));
      });
    }
    
    write();
    
    return native;
  }
  #end
  
  #if js
  @:noUsing static public inline function ofJsFile(name:String, file:js.html.File, ?options:{ ?chunkSize: Int }):RealSource
    return ofJsBlob(name, file, options);
    
  @:noUsing static public inline function ofJsBlob(name:String, blob:js.html.Blob, ?options:{ ?chunkSize: Int }):RealSource {
    var chunkSize = options == null || options.chunkSize == null ? 4096 : options.chunkSize;
    return tink.io.js.BlobSource.wrap(name, blob, chunkSize);
  }
  #end
  
  #if cs
  @:noUsing static public inline function ofCsStream(name:String, r:cs.system.io.Stream, ?options:{ ?chunkSize: Int }):RealSource {
    var chunkSize = options == null || options.chunkSize == null ? 4096 : options.chunkSize;
    return tink.io.cs.CsSource.wrap(name, r, chunkSize);
  }
  #end

  @:noUsing static public inline function ofInput(name:String, input, ?options:{ ?chunkSize: Int, ?worker:Worker }):RealSource {
    if (options == null)
      options = {};
    return new tink.io.std.InputSource(name, input, options.worker.ensure(), haxe.io.Bytes.alloc(switch options.chunkSize {
      case null: 0x10000;
      case v: v;
    }), 0);
  }
  
  public function chunked():Stream<Chunk, E>
    return this;
  
  @:from static public function ofError(e:Error):RealSource
    return (e : Stream<Chunk, Error>);

  @:from static function ofFuture(f:Future<IdealSource>):IdealSource
    return Stream.flatten((cast f:Future<Stream<Chunk, Noise>>)); // TODO: I don't understand why this needs a cast
    
  @:from static function ofPromised(p:Promise<RealSource>):RealSource
    return Stream #if cs .dirtyFlatten #else .flatten #end (p.map(function (o) return switch o {
      case Success(s): (s:SourceObject<Error>);
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
    
  public inline function transform<A>(transformer:Transformer<E, A>):Source<A>
    return transformer.transform(this);
    
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
    if(len == 0) return cast Source.EMPTY;
    return this.regroup(function(chunks:Array<Chunk>) {
      if(len <= 0) return Terminated(None);
      var chunk = chunks[0];
      var length = chunk.length;
      var out = 
        if(len == length)
          Terminated(Some(Stream.single(chunk)));
        else
          Converted(Stream.single(if(len < length) chunk.slice(0, len) else chunk));
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
      before: Stream #if cs .dirtyPromise #else .promise #end(s.next(function(p):SourceObject<Error> return switch p.a {
        case Some(chunk): (chunk:RealSource);
        case None: src;
      })),
      delimiter: s.next(function(p) return switch p.a {
        case Some(_): delim;
        case None: new Error(NotFound, 'Delimiter not found');
      }),
      after: Stream #if cs .dirtyPromise #else .promise #end(s.next(function(p):SourceObject<Error> return p.b)),
    }
  }
  
  static public function parseStream<R>(s:RealSource, p:StreamParser<R>):RealStream<R>
    return StreamParser.parseStream(s, p);
    
  static public function idealize(s:RealSource, rescue:Error->RealSource):IdealSource
    return (s.chunked().idealize(rescue):StreamObject<Chunk, Noise>);
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
      before: s.before.idealize(function(e) return Source.EMPTY),
      delimiter: s.delimiter,
      after: s.after.idealize(function(e) return Source.EMPTY),
    }
  }
}
