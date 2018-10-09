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
      case Depleted if(cursor.currentPos < cursor.length): 
        Future.sync(Parsed(finish(), mk(Chunk.EMPTY)));
      case Depleted if(!resume):
        Future.sync(Parsed(finish(), flush()));
      case Depleted:
        switch p.eof(cursor) {
          case Success(result):
            consume(result).map(function (_) return Parsed(finish(), flush()));
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
          case Parsed(result, rest):
            s = rest;
            step(Link(result, Generator.stream(next)));
          case Invalid(e, _) | Broke(e): step(Fail(e));
      });
    });
  }
}

class Splitter extends BytewiseParser<Option<Chunk>> {
  var delim:Chunk;
  var buf = Chunk.EMPTY;
  public function new(delim) {
    this.delim = delim;
  }
  override function read(char:Int):ParseStep<Option<Chunk>> {
    
    if(char == -1) return Done(None);
    
    buf = buf & String.fromCharCode(char);
    return if(buf.length >= delim.length) {
      var bcursor = buf.cursor();
      bcursor.moveBy(buf.length - delim.length);
      var dcursor = delim.cursor();
      
      for(i in 0...delim.length) {
        if(bcursor.currentByte != dcursor.currentByte) {
          return Progressed;
        }
        else {
          bcursor.next();
          dcursor.next();
        }
      }
      var out = Done(Some(buf.slice(0, bcursor.currentPos - delim.length)));
      buf = Chunk.EMPTY;
      return out;
      
    } else {
      
      Progressed;
      
    }
  }
}

class SimpleBytewiseParser<Result> extends BytewiseParser<Result> {
  
  var _read:Int->ParseStep<Result>;

  public function new(f)
    this._read = f;

  override public function read(char:Int)
    return _read(char); 
}

class BytewiseParser<Result> implements StreamParserObject<Result> { 

  function read(char:Int):ParseStep<Result> {
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
    return switch read( -1) {
      case Progressed: Failure(new Error(UnprocessableEntity, 'Unexpected end of input'));
      case Done(r): Success(r);
      case Failed(e): Failure(e);
    }
  
  
}

interface StreamParserObject<Result> {
  function progress(cursor:ChunkCursor):ParseStep<Result>;
  function eof(rest:ChunkCursor):Outcome<Result, Error>;
}