package tink.io;

import tink.chunk.ChunkCursor;
import tink.io.PipeOptions;
import tink.io.Sink;
import tink.streams.Stream;

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
  static function doParse<R, Q, F>(source:Stream<Chunk, Q>, p:StreamParserObject<R>, consume:R->Future<{ resume: Bool }>, finalize:Void->F):Future<ParseResult<F, Q>> {
    var cursor = Chunk.EMPTY.cursor();
    function mk(source:Source<Q>)
      return source.prepend(cursor.right());
    return source.forEach(function (chunk:Chunk):Future<Handled<Error>> {
      cursor.shift(chunk);
      return switch p.progress(cursor) {
        case Progressed: 
          Future.sync(Resume);
        case Done(v): 
          consume(v).map(function (o) return if (o.resume) Resume else Finish);
        case Failed(e): 
          Future.sync(Clog(e));
      }
    }).flatMap(function (c) return switch c {
      case Halted(rest): 
        Future.sync(Parsed(finalize(), mk(rest)));
      case Clogged(e, rest):
        Future.sync(Invalid(e, mk(rest)));
      case Failed(e):
        Future.sync(Broke(e));
      case Depleted if(cursor.currentPos < cursor.length): 
        Future.sync(Parsed(finalize(), mk(Chunk.EMPTY)));
      case Depleted:
        switch p.eof(cursor) {
          case Success(result):
            consume(result).map(function (_) return Parsed(finalize(), cursor.flush()));
          case Failure(e):
            Future.sync(Invalid(e, cursor.flush()));
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
  
}

class Splitter extends BytewiseParser<Chunk> {
  var delim:Chunk;
  var buf = Chunk.EMPTY;
  public function new(delim) {
    this.delim = delim;
  }
  override function read(char:Int):ParseStep<Chunk> {
    
    buf = buf & String.fromCharCode(char);
    return if(buf.length > delim.length) {
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
      
      bcursor.moveBy(-delim.length);
      Done(bcursor.left());
      
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