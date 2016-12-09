package tink.io;

import haxe.io.*;
import tink.io.*;
import tink.io.Pipe;
import tink.io.Source;

using tink.CoreApi;

abstract IdealSource(IdealSourceObject) to IdealSourceObject from IdealSourceObject to Source {
  
	public inline function read(into:Buffer, max:Int = 1 << 30):Future<Progress>
    return this.readSafely(into, max);
    
	public inline function close():Future<Noise>
    return this.closeSafely();
    
  public inline function all():Future<Bytes>
    return this.allSafely();
    
  public function skip(length:Int):IdealSource
    return (this:Source).skip(length).idealize(function(_) {}); // TODO: not the best way...
    
  public function limit(length:Int):IdealSource
    return (this:Source).limit(length).idealize(function(_) {}); // TODO: not the best way...
    
	public inline function prepend(other:IdealSource):IdealSource
    return CompoundSource.of(other, this);
    
	public inline function append(other:IdealSource):IdealSource
    return CompoundSource.of(this, other);
    
	public inline function pipeTo<Out>(dest:PipePart<Out, Sink>, ?options):Future<PipeResult<Noise, Out>>
    return this.pipeSafelyTo(dest, options);
  
  static public inline function ofBytes(b:Bytes, offset:Int = 0):IdealSource 
    return 
      if (b == null) Empty.instance;
      else new ByteSource(b, offset);
    
  @:from static function fromBytes(b:Bytes):IdealSource
    return ofBytes(b);
    
  @:from static function fromString(s:String):IdealSource
    return 
      if (s == null) (Empty.instance : IdealSourceObject);
      else ofBytes(Bytes.ofString(s));//TODO: use direct conversion where available
  
  static public function create():SyntheticIdealSource
    return new SyntheticIdealSource();
    
}

interface IdealSourceObject extends SourceObject {
  function allSafely():Future<Bytes>;
  function pipeSafelyTo<Out>(dest:PipePart<Out, Sink>, ?options:{ ?end:Bool }):Future<PipeResult<Noise, Out>>;
  function readSafely(into:Buffer, max:Int = 1 << Buffer.MAX_WIDTH):Future<Progress>;
  function closeSafely():Future<Noise>;
}

class IdealizedSource extends IdealSourceBase {
  var target:Source;
  var onError:Callback<Error>;
  
  public function new(target, onError) {
    this.target = target;
    this.onError = onError;
  }
  
  override public function readSafely(into:Buffer, max = 1 << Buffer.MAX_WIDTH):Future<Progress>  
    return target.read(into, max).map(function (x) return switch x {
      case Success(v): v;
      case Failure(e): 
        onError.invoke(e);
        Progress.EOF;
    });
    
  override public function closeSafely():Future<Noise>
    return target.close().map(function (x) return switch x {
      case Failure(e):
        onError.invoke(e);
        Noise;
      case Success(v): v;
    });
  
}

class Empty extends IdealSourceBase {
  function new() {}
  override public function readSafely(into:Buffer, max = 1 << Buffer.MAX_WIDTH):Future<Progress> 
    return Future.sync(Progress.EOF);
  
  override public function closeSafely()
    return Future.sync(Noise);
    
  public function toString()
    return '[Empty source]';
  
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
  
  function doRead(into:Buffer, max):Progress {
    if (closed || buf.length == 0) return Progress.EOF;
    var src = buf[0];
    var ret = into.readFrom(src, max);
    if (src.position == src.length)
      buf.shift();
    return ret;
  }
  
  public function end() {
    writable = false;
    if (queue.length > 0)
      closeSafely();
  }
  
  override public function readSafely(into:Buffer, max = 1 << Buffer.MAX_WIDTH):Future<Progress> {
    if (closed)
      return Future.sync(Progress.EOF);
      
    if (buf.length > 0 || !writable) 
      return Future.sync(doRead(into, max));
      
    var trigger = Future.trigger();
    
    queue.push(trigger);
    
    return trigger.asFuture().map(function (_) return doRead(into, max));
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
  
  override public function idealize(onError:Callback<Error>):IdealSource
    return this;
  
  public function allSafely():Future<Bytes> {
    return Future.async(function (cb) {
      this.pipeSafelyTo(IdealSink.inMemory(function (buf) {
        cb(buf.getBytes());
      }), { end: true });
    });
  }
   
  override public function all():Surprise<Bytes, Error>
    return allSafely().map(Success);
    
  public function readSafely(into:Buffer, max = 1 << Buffer.MAX_WIDTH):Future<Progress>  
    return throw 'abstract';
    
  public function closeSafely():Future<Noise>
    return throw 'abstract';
    
  override public inline function close() 
    return closeSafely().map(Success);
      
  override public inline function read(into:Buffer, max = 1 << Buffer.MAX_WIDTH) 
    return readSafely(into, max).map(Success);
    
  public function pipeSafelyTo<Out>(dest:PipePart<Out, Sink>, ?options:{ ?end:Bool }):Future<PipeResult<Noise, Out>>
    return Future.async(function (cb) Pipe.make(this, dest, options, function (_, res) cb(res)));
    
}

class ByteSource extends IdealSourceBase {
  //TODO: this is not optimal. It should rather have a whole hunk of bytes
  var data:Bytes;
  var pos:Int;
  
  public function new(data, offset:Int = 0) {
    this.data = data;
    this.pos = offset;
  }
  
  function readBytes(into:Bytes, offset:Int, len:Int):Int
    return
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
      
  override public function allSafely():Future<Bytes> {
    
    var ret = 
      if (pos == 0) data;
      else data.sub(pos, data.length - pos);
      
    data = Buffer.ZERO_BYTES;
    pos = 0;
    
    return Future.sync(ret);
  }
  
  
  override public function append(other:Source):Source
    return 
      switch Std.instance(other, ByteSource) {
        case null: super.append(other);
        case v: this.merge(v);
      }
      
  override public function prepend(other:Source):Source
    return 
      switch Std.instance(other, ByteSource) {
        case null: super.append(other);
        case v: v.merge(this);
      }
      
  function merge(that:ByteSource) {
    
    var l1 = this.data.length - this.pos,
        l2 = that.data.length - that.pos;
        
    var bytes = Bytes.alloc(l1 + l2);
    bytes.blit(0, this.data, this.pos, l1);
    bytes.blit(l1, that.data, that.pos, l2);
    
    return new ByteSource(bytes, 0);
  }
  
  override public function pipeTo<Out>(dest:PipePart<Out, Sink>, ?options:{?end:Bool}):Future<PipeResult<Error, Out>> {
    var dest:Sink = dest;
    var buf = Buffer.wrap(data, pos, data.length - pos);
    var initial = buf.available;
    
    return 
      Future.async(function (cb) 
        dest.writeFull(buf).handle(function (o) {
          
          pos += buf.available - initial;
          
          cb(cast switch o {
            case Success(true):  
              if (options != null && options.end)
                dest.close();
              AllWritten;
            case Success(false):
              SinkEnded;
            case Failure(e): 
              SinkFailed(e);
          });
          
          if (pos == data.length) closeSafely();
          
        })
      );
  }
      
  public function toString()
    return '[Byte Source $pos/${data.length}]';
    
  override public function readSafely(into:Buffer, max = 1 << Buffer.MAX_WIDTH):Future<Progress>
    return Future.sync(into.readFrom(this, max));
  
  override public function closeSafely():Future<Noise> {
    data = Buffer.ZERO_BYTES;
    pos = 0;
    return Future.sync(Noise);
  }
}

private class CompoundSource extends IdealSourceBase {
  var parts:Array<IdealSource>;
  public function new(parts)
    this.parts = parts;
  
  override public function pipeSafelyTo<Out>(dest:PipePart<Out, Sink>, ?options:{ ?end: Bool }):Future<PipeResult<Noise, Out>> 
    return Future.async(function (cb) {
      function next()
        switch parts {
          case []: cb(AllWritten);
          case v: 
            parts[0].pipeTo(dest, if (parts.length == 1) options else null).handle(function (x) switch x {
              case AllWritten:
                parts.shift().close();
                next();
              default:
                cb(x);
            });
        };
        
      next();
    });
  
  override public function closeSafely():Future<Noise> 
    return 
      switch parts {
        case []: Future.sync(Noise);
        default: Future.ofMany([for (p in parts) p.close()]).map(function (_) return Noise);
      }
  
  override public function readSafely(into:Buffer, max = 1 << 30):Future<Progress>
    return switch parts {
      case []: 
        Future.sync(Progress.EOF);
      default:
        Future.async(function (cb) 
          parts[0].read(into).handle(function (p)
            if (p.isEof) {
              parts.shift().close();
              readSafely(into, max);
            }
            else cb(p)
          )
        );
    }
  
  static public function of(a:IdealSource, b:IdealSource) //TODO: consider dealing with null
    return new CompoundSource(
      switch [Std.instance(a, CompoundSource), Std.instance(b, CompoundSource)] {
        case [null, null]: 
          [a, b];
        case [null, { parts: p }]: 
          [a].concat(p);  
        case [{ parts: p }, null]: 
          p.concat([b]);
        case [{ parts: p1 }, { parts: p2 }]:
          p1.concat(p2);
      }
    );
}