package tink.io;

import haxe.io.*;
import tink.io.*;
import tink.io.Pipe.PipeResult;
import tink.io.Source;

using tink.CoreApi;

@:forward
abstract IdealSource(IdealSourceObject) to IdealSourceObject from IdealSourceObject to Source {
  static public inline function ofBytes(b:Bytes, ?offset:Int = 0):IdealSource 
    return 
      if (b == null) Empty.instance;
      else new ByteSource(b, offset);
    
  @:from static function fromBytes(b:Bytes)
    return ofBytes(b);
    
  @:from static function fromString(s:String)
    return 
      if (s == null) Empty.instance;
      else ofBytes(Bytes.ofString(s));
  
  static public function create():SyntheticIdealSource
    return new SyntheticIdealSource();
    
}

interface IdealSourceObject extends SourceObject {
  function readSafely(into:Buffer):Future<Progress>;
  function closeSafely():Future<Noise>;
}

class Empty extends IdealSourceBase {
  function new() {}
  override public function readSafely(into:Buffer):Future<Progress> 
    return Future.sync(Progress.EOF);
  
  override public function closeSafely()
    return Future.sync(Noise);
  
  static public var instance(default, null):Empty = new Empty();
}

class SyntheticIdealSource extends IdealSourceBase {
  
  var buf:Array<BytesInput>;
  var queue:Array<FutureTrigger<Noise>>;
  
  public var writable(default, null):Bool = true;
  
  public var closed(get, never):Bool;  
    inline function get_closed()
      return buf == null;
  
  public function new() {
    buf = [];
    queue = [];
  }
  
  function doRead(into:Buffer):Progress {
    if (closed || buf.length == 0) return Progress.EOF;
    var src = buf[0];
    var ret = into.readFrom(src);
    if (src.position == src.length)
      buf.shift();
    return ret;
  }
  
  public function end() {
    writable = false;
    if (queue.length > 0)
      closeSafely();
  }
  
  override public function readSafely(into:Buffer):Future<Progress> {
    if (closed)
      return Future.sync(Progress.EOF);
      
    if (buf.length > 0 || !writable) 
      return Future.sync(doRead(into));
      
    var trigger = Future.trigger();
    
    queue.push(trigger);
    
    return trigger.asFuture().map(function (_) return doRead(into));
  }
  
  public function write(bytes:Bytes):Bool {
    if (closed || !writable)
      return false;
      
    buf.push(new BytesInput(bytes));
    if (queue.length > 0 && (buf.length > 0 || !writable))
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
  
  function readBytes(into:Bytes, offset:Int, len:Int):Int {
    var ret =
      if (pos >= data.length)
        Progress.EOF;
      else if (len <= 0) 
        Progress.NONE;
      else if (pos + len > data.length) 
        readBytes(into, offset, data.length - pos);
      else {
        into.blit(offset, data, pos, len);
        pos += len;
        len;
      }
    //trace(ret);  
    return ret;
  }
  
  public function toString()
    return '[Byte Source $pos/${data.length}]';
  
  override public function pipeTo(dest:Sink):Future<PipeResult> {
    return 
      //if (Std.is(dest, NodeSink)) {
        //var dest:NodeSink = cast dest;
        //@:privateAccess {
          //dest.target.
        //}
      //}
      //else 
      {
        @:privateAccess {
          var pipe = new Pipe(this, dest, data);
          pipe.buffer.seal();
          pipe.buffer.available = data.length;
          pipe.flush();
          pipe.result;
        }
      }
  }
  
    
  override public function readSafely(into:Buffer):Future<Progress>
    return Future.sync(into.readFrom(this));
  
  override public function closeSafely():Future<Noise> {
    data = Buffer.ZERO_BYTES;
    pos = 0;
    return Future.sync(Noise);
  }
}