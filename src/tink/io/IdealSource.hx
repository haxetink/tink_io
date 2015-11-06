package tink.io;

import haxe.io.*;
import tink.io.*;
import tink.io.Source;

using tink.CoreApi;

@:forward
abstract IdealSource(IdealSourceObject) to IdealSourceObject from IdealSourceObject to Source {
  static public inline function ofBytes(b:Bytes, ?offset:Int = 0):IdealSource 
    return new ByteSource(b, offset);
    
  @:from static function fromBytes(b:Bytes)
    return ofBytes(b);
    
  
  static public function create():SyntheticSource
    return new SyntheticSource();
    
}

interface IdealSourceObject extends SourceObject {
  function readSafely(into:Buffer):Future<Progress>;
  function closeSafely():Future<Noise>;
}

class SyntheticSource extends IdealSourceBase {
  
  var buf:Array<BytesInput>;
  var queue:Array<FutureTrigger<Noise>>;
  
  public var closed(get, never):Bool;  
    inline function get_closed()
      return buf == null;
  
  public function new() {
    buf = [];
    queue = [];
  }
  
  function doRead(into:Buffer):Progress {
    if (closed) return Progress.EOF;
    var src = buf[0];
    var ret = into.readFrom(src);
    if (src.position == src.length)
      buf.pop();
    return ret;
  }
  
  override public function readSafely(into:Buffer):Future<Progress> {
    if (closed)
      return Future.sync(Progress.EOF);
      
    if (buf.length > 0) 
      return Future.sync(doRead(into));
      
    var trigger = Future.trigger();
    
    queue.push(trigger);
    
    return trigger.asFuture().map(function (_) return doRead(into));
  }
  
  public function write(bytes:Bytes):Bool {
    if (closed)
      return false;
      
    buf.push(new BytesInput(bytes));
    if (queue.length > 0 && buf.length > 0)
      queue.shift().trigger(Noise);
      
   return true;
  }
  
  override public function closeSafely():Future<Noise> {
    if (!closed) {
      buf = null;
      
      for (q in queue)
        q.trigger(Noise);
        
      queue = null;
    }
    return Future.sync(Noise);
  }
}

class IdealSourceBase extends SourceBase implements IdealSourceObject {
  
  public function readSafely(into:Buffer):Future<Progress>  
    return throw 'abstract';
    
  public function closeSafely():Future<Noise>
    return throw 'abstract';
    
  override public inline function close() 
    return closeSafely().map(Success);
      
  override public inline function read(into:Buffer) 
    return readSafely(into).map(Success);
}

class ByteSource extends IdealSourceBase {
  var data:Bytes;
  var pos:Int;
  
  public function new(data, ?offset:Int = 0) {
    this.data = data;
    this.pos = offset;
  }
  
  function readBytes(into:Bytes, offset:Int, len:Int):Int 
    return
      if (len <= 0) 
        Progress.NONE;
      else if (pos + len > data.length) 
        readBytes(into, offset, data.length - pos);
      else if (len == 0)
        Progress.EOF;
      else {
        into.blit(offset, data, pos, len);
        pos += len;
        len;
      }
  
  override public function readSafely(into:Buffer):Future<Progress>
    return Future.sync(into.readFrom(this));
  
  override public function closeSafely():Future<Noise> {
    data = Buffer.ZERO_BYTES;
    pos = 0;
    return Future.sync(Noise);
  }
}