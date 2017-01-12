package tink.io;

import haxe.io.Bytes;
import tink.streams.IdealStream;
import tink.streams.Stream;

abstract IdealSource(IdealSourceObject) from IdealSourceObject to IdealSourceObject {
  
  @:from static inline function ofChunk(c:Chunk):IdealSource
    return new Single(c);
    
  @:from static inline function ofBytes(b:Bytes) 
    return ofChunk(b);
    
  @:from static inline function ofString(s:String) 
    return ofChunk(s);
    
}

typedef IdealSourceObject = IdealStreamObject<Chunk>;