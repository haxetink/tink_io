package tink.io;

import tink.chunk.ChunkCursor;
import tink.io.PipeOptions;
import tink.io.Sink;
import tink.streams.Stream;
import tink.streams.RealStream;

using tink.CoreApi;

enum ParseStep<Result> {
  Progressed;
  Done(r:Result);
  Failed(e:Error);
}

enum ParseResult<Result, Quality> {
  Finished:ParseResult<Result, Quality>;
  Parsed(data:Result, rest:Source<Quality>):ParseResult<Result, Quality>;
  Invalid(e:Error, rest:Source<Quality>):ParseResult<Result, Quality>;
  Broke(e:Error):ParseResult<Result, Error>;
}


abstract StreamParser<Result>(StreamParserObject<Result>) from StreamParserObject<Result> to StreamParserObject<Result> {
  static function doParse<R, Q, F>(source:Stream<Chunk, Q>, p:StreamParserObject<R>, consume:R->Future<{ resume: Bool }>, finish:Void->F):Future<ParseResult<F, Q>> {
    var cursor = Chunk.EMPTY.cursor();
    var resume = true;
    function mk(source:Source<Q>) {
      return if(cursor.currentPos < cursor.length)
        source.prepend(cursor.right());
      else
        source;
    }
      
    function flush():Source<Q>
      return switch cursor.flush() {
        case c if(c.length == 0): cast Source.EMPTY;
        case c: c;
      }
      
    return source.forEach(function (chunk:Chunk):Future<Handled<Error>> {
      if(chunk.length == 0) return Future.sync(Resume); // TODO: review this fix
      cursor.shift(chunk);
      
      return Future.async(function(cb) {
        function next() {
          cursor.shift();
          var lastPos = cursor.currentPos;
          switch p.progress(cursor) {
            case Progressed:
              if(lastPos != cursor.currentPos && cursor.currentPos < cursor.length) next() else cb(Resume);
            case Done(v): 
              consume(v).handle(function (o) {
                resume = o.resume;
                if (resume) {
                  if(lastPos != cursor.currentPos && cursor.currentPos < cursor.length) next() else cb(Resume);
                } else
                  cb(Finish);
              });
            case Failed(e): 
              cb(Clog(e));
          }
        }
        next();
      });
    }).flatMap(function (c) return switch c {
      case Halted(rest):
        Future.sync(Parsed(finish(), mk(rest)));
      case Clogged(e, rest):
        Future.sync(Invalid(e, mk(rest)));
      case Failed(e):
        Future.sync(Broke(e));
      // case Depleted if(cursor.currentPos < cursor.length): 
      //   Future.sync(Parsed(finish(), mk(Chunk.EMPTY)));
      case Depleted if(!resume):
        Future.sync(Parsed(finish(), flush()));
      case Depleted:
        switch p.eof(cursor) {
          case Success(Some(result)):
            consume(result).map(function (_) return Parsed(finish(), flush()));
          case Success(None):
            Future.sync(Finished);
          case Failure(e):
            Future.sync(Invalid(e, flush()));
        }     
    });
  }
  static public function parse<R, Q>(s:Source<Q>, p:StreamParser<R>):Future<ParseResult<R, Q>> {
    var res = null;
    function onResult(r) {
      res = r;
      return Future.sync({ resume: false });
    }
    return doParse(s, p, onResult, function () return res);
  }
  
  static public function parseStream<R, Q>(s:Source<Q>, p:StreamParser<R>):RealStream<R> {
    return Generator.stream(function next(step) {
      if(s.depleted)
        step(End);
      else 
        parse(s, p).handle(function(o) switch o {
          case Finished:
            step(End);
          case Parsed(result, rest):
            s = rest;
            step(Link(result, Generator.stream(next)));
          case Invalid(e, _) | Broke(e): step(Fail(e));
      });
    });
  }
}

class Splitter implements StreamParserObject<Chunk> {
  var delim:Chunk;
  var scanned:Chunk = Chunk.EMPTY;
  
  public function new(delim) {
    this.delim = delim;
  }
  
  public function progress(cursor:ChunkCursor) {
    return switch cursor.seek(delim) {
      case Some(chunk):
        final result = scanned & chunk;
        scanned = Chunk.EMPTY;
        Done(result);
      case None:
        scanned &= cursor.sweepTo(cursor.length - delim.length); // move to end
        Progressed;
    }
  }
  
  public function eof(rest:ChunkCursor) {
    return Success(rest.length == 0 ? None : Some(rest.seek(delim).or(() -> scanned & rest.right())));
  }
}

class SimpleBytewiseParser<Result> extends BytewiseParser<Result> {
  
  var _read:Int->ParseStep<Result>;
  var _readEof:Void->Outcome<Option<Result>, Error>;

  public function new(read, readEof) {
    this._read = read;
    this._readEof = readEof;
    
  }

  override public function read(char:Int)
    return _read(char); 

  override function readEof():Outcome<Option<Result>, Error>
    return _readEof();
}

class BytewiseParser<Result> implements StreamParserObject<Result> { 

  function read(char:Int):ParseStep<Result> {
    return throw 'abstract';
  }

  function readEof():Outcome<Option<Result>, Error> {
    return throw 'abstract';
  }
  
  public function progress(cursor:ChunkCursor) {
    
    do switch read(cursor.currentByte) {
      case Progressed:
      case Done(r): 
        cursor.next();
        return Done(r);
      case Failed(e):
        return Failed(e);
    } while (cursor.next());
    
    return Progressed;
  }
  
  public function eof(rest:ChunkCursor) 
    return readEof();
}

interface StreamParserObject<Result> {
  function progress(cursor:ChunkCursor):ParseStep<Result>;
  function eof(rest:ChunkCursor):Outcome<Option<Result>, Error>;
}