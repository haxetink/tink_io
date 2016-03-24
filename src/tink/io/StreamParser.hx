package tink.io;

import haxe.ds.Option;
import haxe.io.Bytes;
import haxe.io.BytesBuffer;
using tink.CoreApi;

/**
 * Parsers, once created, should not cause side effects outside themselves, otherwise you will get really weird bugs.
 */
interface StreamParser<Result> {
  function minSize():Int;
  function progress(buffer:Buffer):Outcome<Option<Result>, Error>;
  function eof():Outcome<Result, Error>;
}

enum ParseStep<Result> {
  Failed(e:Error);
  Done(r:Result);
  Progressed;
}

class Splitter implements StreamParser<Bytes> {
  var atEnd:Bool;
  var out:BytesBuffer;
  var delim:Bytes;
  var result:Option<Bytes>;
  
  public function minSize()
    return delim.length;
  
  public function new(delim) {
    this.delim = delim;
    //reset();
  }
  
  function reset() {
    this.out = new BytesBuffer();
  }
  
  function writeBytes(bytes:Bytes, start:Int, length:Int) {
    
    if (!atEnd) {
      length -= delim.length;
      if (length < 0) length = 0;
    }
    
    if (length > 0) {
      for (i in 0...length) {
        var found = true;
        for (dpos in 0...delim.length) {
          if (bytes.get(start + i + dpos) != delim.get(dpos)) {
            found = false;
            break;
          }
        }
        if (found) {
          out.addBytes(bytes, start, i);
          result = Some(out.getBytes());
          reset();
          return i + delim.length;
        }
      }
      out.addBytes(bytes, start, length);
    }
    
    return length;
  }
  
  public function progress(buffer:Buffer):Outcome<Option<Bytes>, Error> {
    if (result != None) {
      reset();
      result = None;
    }
    
    if (buffer.size - buffer.zero <= delim.length) 
      buffer.align();
    
    atEnd = !buffer.writable;
    buffer.writeTo(this);
    
    return Success(result);
  }
  public function eof():Outcome<Bytes, Error> {
    return Success(out.getBytes());
  }
}

class ByteWiseParser<Result> implements StreamParser<Result> {
  
  var result:Outcome<Option<Result>, Error>;
  var resume:Outcome<Option<Result>, Error>;
  
  public function new() {
    resume = Success(None);
  }
  
  public function minSize():Int
    return 1;
    
  function read(c:Int):ParseStep<Result>
    return throw 'not implemented';
    
  public function eof():Outcome<Result, Error> 
    return
      switch read(-1) {
        case Failed(e):
          Failure(e);
        case Done(r):
          Success(r);
        default:
          Failure(new Error(UnprocessableEntity, 'Unexpected end of input'));
      }    
      
  function writeBytes(bytes:Bytes, start:Int, length:Int) {
    var data = bytes.getData();
    
    for (pos in start ... start + length) 
      switch read(Bytes.fastGet(data, pos)) {
        case Progressed:
        case Failed(e):
          result = Failure(e);
          return pos - start + 1;
        case Done(r):
          result = Success(Some(r));
          return pos - start + 1;
      }    
      
    return length;
  }
  
  public function progress(buffer:Buffer):Outcome<Option<Result>, Error> {
    result = resume;
    buffer.writeTo(this);
    return result;
  }
}