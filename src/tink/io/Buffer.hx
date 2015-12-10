package tink.io;

import haxe.io.*;
import haxe.io.Error in IoError;
import tink.concurrent.Queue;

using tink.CoreApi;

typedef WritesBytes = { 
	private function writeBytes(from:Bytes, pos:Int, len:Int):Int; 
}

typedef ReadsBytes = {
	private function readBytes(into:Bytes, pos:Int, len:Int):Int; 	
}

class Buffer {
	var bytes:Bytes;
	var raw:BytesData;
  var width:Int;
	public var zero(default, null):Int = 0;
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
			
	function new(bytes, width) {
		this.bytes = bytes;
		this.raw = bytes.getData();
    this.width = width;
	}
	
  /**
   * Seals the buffer
   */
	public function seal()
		this.writable = false;
	
  /**
   * Consolidates the content of the buffer into a single Bytes blob.
   * Does not affect the buffer.
   */
	public function content():Bytes {
		return blitTo(Bytes.alloc(available));
	}
  
  public function blitTo(ret:Bytes) {
		if (zero + available <= size) 
			ret.blit(0, bytes, zero, available);
		else {
			ret.blit(bytes.length - zero, bytes, 0, end);
			ret.blit(0, bytes, zero, bytes.length - zero);
		}
    
    return ret;
  }
		
	public function toString() 
		return '[Buffer $available/$size]';
	
	public inline function hasNext():Bool
		return available > 0;
		
	public inline function next():Int {
		var ret = Bytes.fastGet(raw, zero++);
		available--;
		if (zero >= bytes.length)
			zero -= bytes.length;
		return ret;
	}
	
  /**
   * Attempts adding a byte.
   * 
   * Returns EOF if the buffer is sealed.
   * Returns NONE if the buffer is full.
   */
	public function addByte(byte:Int):Progress {
		if (!writable) return Progress.EOF;
    if (freeBytes == 0) return Progress.NONE;
		bytes.set(end, byte);
		available++;
		return Progress.by(1);
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
        Failure(Error.withData('$operation due to $e', e));
  
	
  /**
   * Writes to a destination with error handling.
   * If the destination raises an exception, then the buffer's state remains entirely unaffected.
   * The same cannot necessarily be said for the destination, i.e. parts of the content may have been successfully written, before the error occurred.
   * 
   * If the buffer handles an error, it is best to reset the destination to a known state, before attempting another write.
   */
	public function tryWritingTo(name:String, dest:WritesBytes):Outcome<Progress, Error> 
		return safely('Failed writing to $name', writeTo.bind(dest));
	
  /**
   * Reads from a source with error handling. See tryWritingTo
   */  
	public function tryReadingFrom(name:String, source:ReadsBytes):Outcome<Progress, Error> 
		return safely('Failed reading from $name', readFrom.bind(source));			
	
  /**
   * Writes contents of the buffer to the destination.
   * If this buffer is readonly and is drained by the write, it is disposed and EOF is returned.
   * If the buffer is empty, NONE is returned.
   * 
   * Use only if you know the destination not to produce exceptions.
   */
	public function writeTo(dest:WritesBytes):Progress {
		
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
			
    if (transfered > 0) {
      zero = (zero + transfered) % bytes.length;
      available -= transfered;
		}
    
    if (!writable && available == 0)
      dispose();
    
		return Progress.by(transfered);
	}	
	
  public function align() {
    if (zero < end) 
      return false;
    
    var copy = 
      if (width > 0)
        allocBytes(width);
      else
        Bytes.alloc(this.size);
        
    blitTo(copy);
    var old = this.bytes;
    this.bytes = copy;
    this.raw = copy.getData();
    this.zero = 0;
    poolBytes(old, width);
    return true;
  }
  
  public function clear() {
    this.zero = 0;
    this.available = 0;
    this.writable = true;
  }
  
  /**
   * Reads from a source into the buffer.
   * Returns EOF if the buffer is sealed.
   * Returns NONE if the buffer is full.
   * 
   * Use only if you know the source not to produce exceptions.
   */
	public function readFrom(source:ReadsBytes):Progress {
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
		
    if (transfered > 0) {
      available += transfered;
    }
    
		return Progress.by(transfered);
	}
    
	static public var ZERO_BYTES(default, null) = Bytes.alloc(0);
  
  static function poolBytes(b:Bytes, width:Int) 
    if (width >= MIN_WIDTH)
      pool[width - MIN_WIDTH].add(b);
  
	function dispose() 
		if (size > 0) {
      var old = this.bytes;
			this.bytes = ZERO_BYTES;
			this.raw = this.bytes.getData();
			this.zero = 0;
			this.available = 0;
      poolBytes(old, width);
		}
    
  static public function allocMin(minSize:Int) {
    
    if (minSize > 1 << 28)
      'Cannot allocate buffer of size $minSize';
    
    var width = 16;
    var size = 1 << width;
    
    while (size < minSize) 
      size = 1 << ++width;
    
    return alloc(width);
  }
  
  static public function alloc(?width:Int = 17) {
    
    if (width < MIN_WIDTH)
      width = MIN_WIDTH;
      
    if (width > MAX_WIDTH)
      width = MAX_WIDTH;
      
    return new Buffer(allocBytes(width), width);
  }
  
  static public function allocBytes(width:Int)
    return 
      switch pool[width - MIN_WIDTH].pop() {
        case null: Bytes.alloc(1 << width);
        case v: v;
      }
      
  static public function releaseBytes(bytes:Bytes) {
    
    for (width in MIN_WIDTH...MAX_WIDTH)
      if (bytes.length == 1 << width) {
        poolBytes(bytes, width);
        return true;
      }
    
    return false;
    
  }
  
  static inline var MIN_WIDTH = 10;
  static inline var MAX_WIDTH = 28;
  
  static var pool = [for (i in MIN_WIDTH...MAX_WIDTH) new Queue<Bytes>()];
  
  static public function unmanaged(bytes:Bytes) {
    return new Buffer(bytes, -1);
  }
}