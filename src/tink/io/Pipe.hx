package tink.io;

import haxe.io.Bytes;
import tink.io.Sink;
import tink.io.Source;

using tink.CoreApi;

class Pipe {
  var buffer:Buffer;
  var source:Source;
  var dest:Sink;
  var total = 0;
	var result:FutureTrigger<PipeResult>;
  
  function new(source, dest, ?bytes) {
    if (bytes == null)
      bytes = Bytes.alloc(0x40000);
		this.source = source;
		this.dest = dest;
		
		this.buffer = new Buffer(bytes);
		this.result = Future.trigger();
		read();
  }
  
  function yield(s:PipeResultStatus)
    result.trigger(new PipeResult(total, s));
  
	function read()
		source.read(buffer).handle(function (o) switch o {
			case Success(_.isEof => true):
				buffer.seal();
				flush();
			case Success(v):
        flush();
			case Failure(e):
        yield(SourceFailed(e));
		});
    
	function flush() {
		dest.write(buffer).handle(function (o) switch o {
			case Success(_.isEof => true):
        yield(if (buffer.available > 0) SinkEnded(buffer) else AllWritten);
			case Success(v):
        total += v.bytes;
				if (buffer.available == 0)
					read();
				else 
					flush();
			case Failure(f):
				source.close();
        yield(SinkFailed(f, buffer));
		});
	}	
  
  static var queue = [];
  
  static public function make(from:Source, to:Sink, ?bytes):Future<PipeResult> {
		var p = new Pipe(from, to, bytes);
		return p.result.asFuture();    
  }
}

abstract PipeResult(Pair<Int, PipeResultStatus>) {
  
  public var bytesWritten(get, never):Int;
    inline function get_bytesWritten()
      return this.a;
  
  public var status(get, never):PipeResultStatus;
    inline function get_status()
      return this.b;
      
  public function new(bytesWritten, status)
    this = new Pair(bytesWritten, status);
     
  @:to public function toString() 
    return '[Piped $bytesWritten bytes - $status]';
    
}

enum PipeResultStatus {
  AllWritten;
  SinkEnded(rest:Buffer);
  SinkFailed(e:Error, rest:Buffer);
  SourceFailed(e:Error);
}