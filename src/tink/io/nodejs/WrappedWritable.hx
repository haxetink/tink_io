package tink.io.nodejs;

import js.node.Buffer;
import js.node.stream.Writable;
using tink.CoreApi;

class WrappedWritable {
  
  var ended:Promise<Bool>;
  var name:String;
  var native:IWritable;
      
  public function new(name, native) {
    
    this.name = name;
    this.native = native;
    
    this.ended = Future.async(function (cb) {
      native.once('end', function () cb(Success(false)));
      native.once('finish', function () cb(Success(false)));
      native.once('close', function () cb(Success(false)));
      native.on('error', function (e:{ code:String, message:String }) cb(Failure(new Error('${e.code}: ${e.message}'))));            
    });
    
  }
  
  public function end():Promise<Bool> {
    var didEnd = false;
    
    ended.handle(function () didEnd = true).dissolve();
    
    if (didEnd)
      return false;
    
    native.end();
    
    return ended.next(function (_) return true);
  }
  
  public function write(chunk:Chunk):Promise<Bool> 
    return Future.async(function (cb) {
      if(chunk.length == 0) {
        cb(Success(true));
        return;
      }
      var buf = 
        if (Buffer.isBuffer(untyped chunk.buffer)) untyped chunk.buffer;
        else Buffer.hxFromBytes(chunk.toBytes());//TODO: the above branch is ugly and this one is wasteful
      native.write(buf, cb.bind(Success(true)));
    }).first(ended);
}