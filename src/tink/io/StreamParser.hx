package tink.io;

import haxe.ds.Option;
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
    
		return 
      if (buffer.available == 0 && buffer.writable == false)
        eof().map(Some);
      else
        resume;
	}
	
}