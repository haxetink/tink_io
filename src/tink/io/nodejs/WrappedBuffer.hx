package tink.io.nodejs;

import haxe.io.Bytes;
import js.node.Buffer;
import tink.Chunk;

class WrappedBuffer implements ChunkObject {
  
  public var buffer:Buffer;
  
  public function new(buffer) {
    this.buffer = buffer;
  }
  
  public function getCursor():ChunkCursor
    return (toBytes() : Chunk).cursor();
    
  public function flatten(into)
    ((toBytes() : Chunk) : ChunkObject).flatten(into);
    
  public function getLength():Int
    return buffer.length;
    
  public function slice(from:Int, to:Int):Chunk
    return new WrappedBuffer(buffer.slice(from, to));
  
  public function toString():String
    return buffer.toString();
    
  public function toBytes():Bytes {
    var copy = alloc(buffer.length);
    buffer.copy(copy);
    return copy.hxToBytes();
  }

  static var alloc:Int->Buffer = 
    if (untyped __js__('"allocUnsafe" in Buffer')) Buffer.allocUnsafe;
    else function (size) return new Buffer(size);
    
  public function blitTo(target:Bytes, offset:Int):Void
    return buffer.copy(Buffer.hxFromBytes(target), offset);
  
  
}