package tink.io;

import haxe.ds.Option;
import haxe.io.Bytes;
import haxe.io.BytesBuffer;
using tink.CoreApi;

/**
 * Parsers, once created, should not cause side effects outside themselves, otherwise you will get really weird bugs.
 */
interface StreamParser<Result> {
	function progress(buffer:Buffer):Outcome<Option<Result>, Error>;
	function eof():Outcome<Result, Error>;
}

enum ParseStep<Result> {
	Failed(e:Error);
	Done(r:Result);
	Progressed;
}

class Splitter extends ByteWiseParser<Bytes> {
  var buf:BytesBuffer;
  var delims:Array<Delimiter>;
  var delim:String;
  var pool:Array<Delimiter>;
  public function new(delim:String) {
    super();
    this.delims = this.pool = [];
    this.delim = delim;
    reset();
  }
  
  function reset() {
    
    for (d in delims) 
      pool.push(d);
    
    this.delims = [];
    this.buf = new BytesBuffer();
  }
  
  override function read(c:Int):ParseStep<Bytes> {
    if (c == -1) {
      var bytes = this.buf.getBytes();
      reset();
      return Done(bytes);
    }
    
    this.buf.addByte(c);
    
    this.delims.push(switch pool.pop() {
      case null: 
        new Delimiter(delim);
      case v: v;
    });
    
    var nu = [];
    
    for (d in delims) 
      switch d.read(c) {
        case Done(r):
          var bytes = this.buf.getBytes();
          reset();
          return Done(bytes.sub(0, bytes.length - r));
        case Progressed:
          nu.push(d);
        case Failed(e):
          pool.push(d);
      }
    
    delims = nu;
    
    return Progressed;
  }
}

private class Delimiter extends ByteWiseParser<Int> {
  var str:String;
  var pos:Int;
  var failed:ParseStep<Int>;
  
  public function new(str) {
    super();
    this.failed = Failed(null);
    this.str = str;
    this.pos = 0;
  }
  
  override function read(c:Int):ParseStep<Int>
    return
      if (str.charCodeAt(pos) == c) {
        if (++pos == str.length) Done(pos);
        else Progressed;
      }
      else {
        pos = 0;
        failed;
      }
}

class ByteWiseParser<Result> implements StreamParser<Result> {
	
  var resume:Outcome<Option<Result>, Error>;
	
	public function new() 
    resume = Success(None);
	
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
	
	public function progress(buffer:Buffer):Outcome<Option<Result>, Error> {
		
		for (c in buffer) 
			switch read(c) {
				case Progressed:
				case Failed(e):
					return Failure(e);
				case Done(r):
					return Success(Some(r));
			}
    
		return resume;
	}
	
}