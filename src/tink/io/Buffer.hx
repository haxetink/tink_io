package tink.io;

import haxe.io.*;
import haxe.io.Error in IoError;

using tink.CoreApi;

typedef Writable = { 
	private function writeBytes(from:Bytes, pos:Int, len:Int):Int; 
}

typedef Readable = {
	private function readBytes(into:Bytes, pos:Int, len:Int):Int; 	
}

class Buffer {
	var bytes:Bytes;
	var raw:BytesData;
	var zero:Int = 0;
  public var retainCount(default, null) = 0;
  
  public function retain() {
    retainCount++;
    var called = false;
    return function () {
      if (called) return;
      called = true;
      if (--retainCount == 0)
        dispose();
    }
  }
	
	public var writable(default, null):Bool = true;
	public var available(default, null):Int = 0;
	public var size(get, never):Int;
	
		inline function get_size()
			return bytes.length;
	
	var end(get, never):Int;
	
	function get_end()
		return
			(zero + available) % size;
			
	public var freeBytes(get, never):Int;
	
		inline function get_freeBytes()
			return bytes.length - available;
			
	public function new(bytes) {
		this.bytes = bytes;
		this.raw = bytes.getData();
	}
	
	public function seal()
		this.writable = false;
	
	public function content():Bytes {
		var ret = Bytes.alloc(available);
		if (zero < end) 
			ret.blit(0, bytes, zero, available);
		else {
			ret.blit(0, bytes, zero, bytes.length - zero);
			ret.blit(bytes.length - zero, bytes, 0, end);
		}
		return ret;
	}
		
	public function toString() 
		return '[Buffer $available/$size]';
	
	public inline function hasNext()
		return available > 0;
		
	public inline function next() {
		var ret = Bytes.fastGet(raw, zero++);
		available--;
		if (zero >= bytes.length)
			zero -= bytes.length;
		return ret;
	}
	
	public function addByte(byte:Int) {
		if (!writable || available == size) return false;
		bytes.set(end, byte);
		available++;
		return true;
	}
	
	function safely(operation:String, f:Void->Progress):Outcome<Progress, Error>
		return
			try 
				Success(f())
			catch (e:IoError) 
				Success(
					if (e == Blocked) 
						Progress.NONE 
					else 
						Progress.EOF //TODO: try being more specific here
				)
      catch (e:Eof)
        Success(Progress.EOF)
			catch (e:Error) 
				Failure(e)
			catch (e:Dynamic)
				Failure(new Error(operation, e));
  
		
	public function tryWritingTo(name:String, dest:Writable):Outcome<Progress, Error> 
		return safely('Error writing to $name', writeTo.bind(dest));
		
	public function tryReadingFrom(name:String, source:Readable):Outcome<Progress, Error> 
		return safely('Error readong from $name', readFrom.bind(source));			
	
	public function writeTo(dest:Writable):Progress {
		
		if (available == 0) 
			return 
				if (writable) Progress.NONE;
				else {
					dispose();
					Progress.EOF;
				}
		
		var toWrite = 
			if (zero + available > bytes.length)
				bytes.length - zero;
			else
				available;
				
		var transfered = dest.writeBytes(bytes, zero, toWrite);
		
		//if (zero + transfered == bytes.length)
			//transfered += dest.writeBytes(bytes, 0, available - toWrite); 
			
		zero = (zero + transfered) % bytes.length;
		available -= transfered;
		
		return Progress.by(transfered);
	}	
	
	public function readFrom(source:Readable):Progress {
		if (!writable) return Progress.EOF;
		if (available == size) return Progress.NONE;
		
		var toRead = 
			if (end < zero) 
				freeBytes;
			else
				size - end;
				
		var transfered = source.readBytes(bytes, end, toRead);
		
		//if (end + transfered == size)
			//transfered += source.readBytes(bytes, 0, zero);
			
		available += transfered;
		return Progress.by(transfered);
	}
	static public var ZERO_BYTES(default, null) = Bytes.alloc(0);
	function dispose() 
		if (size > 0) {
			this.bytes = ZERO_BYTES;
			this.raw = this.bytes.getData();
			this.zero = 0;
			this.available = 0;
		}
}