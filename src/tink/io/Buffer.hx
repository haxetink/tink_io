package tink.io;

import haxe.io.*;
import haxe.io.Error in IoError;

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
  public var width(default, null):Int = 0;
  public var zero(default, null):Int = 0;
  public var retainCount(default, null) = 0;
  
  public function retain() {
    retainCount++;
    var self = this;
    
    return function () {
      if (self == null) return;
      if (--self.retainCount == 0) 
        self.dispose();
      self = null;
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
    
  function blitTo(ret:Bytes) {
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
  public function tryWritingTo(name:String, dest:WritesBytes, max = 1 << MAX_WIDTH):Outcome<Progress, Error> 
    return safely('Failed writing to $name', writeTo.bind(dest, max));
  
  /**
   * Reads from a source with error handling. See tryWritingTo
   */  
  public function tryReadingFrom(name:String, source:ReadsBytes, max = 1 << MAX_WIDTH):Outcome<Progress, Error> 
    return safely('Failed reading from $name', readFrom.bind(source, max));      
  
  /**
   * Writes contents of the buffer to the destination.
   * If this buffer is readonly and is drained by the write, it is disposed and EOF is returned.
   * If the buffer is empty, NONE is returned.
   * 
   * Use only if you know the destination not to produce exceptions.
   */
  public function writeTo(dest:WritesBytes, max = 1 << MAX_WIDTH):Progress {
    
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
        
    if (max < 0)
      max = 0;
      
    if (max < toWrite)
      toWrite = max;
    
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
  public function readFrom(source:ReadsBytes, max = 1 << MAX_WIDTH):Progress {
    if (!writable) return Progress.EOF;
    if (available == size) return Progress.NONE;
    
    var toRead = 
      if (end < zero) 
        freeBytes;
      else
        size - end;
        
    if (max < 0)
      max = 0;
      
    if (max < toRead)
      toRead = max;
    
    var transfered = source.readBytes(bytes, end, toRead);
    
    //if (end + transfered == size)
      //transfered += source.readBytes(bytes, 0, zero);
    
    if (transfered > 0) {
      available += transfered;
    }
    
    return Progress.by(transfered);
  }
    
  static public var ZERO_BYTES(default, null) = Bytes.alloc(0);
  
  static function poolBytes(b:Bytes, width:Int) {
    if (width >= MIN_WIDTH)
      mutex.synchronized(function () pool[width - MIN_WIDTH].push(b));
  }
  
  function dispose() 
    if (size > 0) {
      var old = this.bytes;
      this.bytes = ZERO_BYTES;
      this.raw = this.bytes.getData();
      this.zero = 0;
      this.available = 0;
      poolBytes(old, width);
    }
    
  static public function sufficientWidthFor(minSize:Int) {
    
    if (minSize > 1 << MAX_WIDTH)
      'Cannot allocate buffer of size $minSize';
    
    var width = DEFAULT_WIDTH;
    var size = 1 << width;
    
    while (size < minSize) 
      size = 1 << ++width;
    
    return width;
  }
  
  static public function alloc(?width:Int = DEFAULT_WIDTH) {
    
    if (width < MIN_WIDTH)
      width = MIN_WIDTH;
      
    if (width > MAX_WIDTH)
      width = MAX_WIDTH;
      
    return new Buffer(allocBytes(width), width);
  }
  
  
  static function allocBytes(width:Int)
    return 
      switch mutex.synchronized(function () return pool[width - MIN_WIDTH].pop()) {
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
  
  static public inline var MIN_WIDTH = 10;
  static public inline var DEFAULT_WIDTH = 15;
  static public inline var MAX_WIDTH = 28;
  
  static var mutex = new Mutex();
  static var pool = [for (i in MIN_WIDTH...MAX_WIDTH) []];
  
  static function unmanaged(bytes:Bytes) {
    return new Buffer(bytes, -1);
  }
  
  static public function wrap(bytes:Bytes, start:Int, len:Int) {
    var ret = Buffer.unmanaged(bytes);
    ret.zero = start;
    ret.available = len;
    return ret;
  }
}

#if tink_concurrent
private typedef Mutex = tink.concurrent.Mutex;
#else
private class Mutex {
  public function new() { }
  public inline function synchronized<A>(f:Void->A) return f();
}
#end