package tink.io.uv;

import hxuv.*;
import tink.uv.Error as UvError;

using tink.CoreApi;
using tink.uv.Result;

class UvStreamWrapper {
  
  public var closed(default, null):Future<Noise>;
  
  var stream:Stream;
  var closedTrigger:FutureTrigger<Noise>;
  
  public function new(stream) {
    this.stream = stream;
    closed = closedTrigger = Future.trigger();
  }
  
  public function read():Promise<Chunk> {
    return Future.async(function(cb) {
      switch stream.readStart(function(status, bytes) {
        stream.readStop();
        if(status.toErrorCode() > 0) cb(Success((bytes:Chunk)));
        else if(status.toErrorCode() == 0) cb(Success(Chunk.EMPTY));
        else {
          close();
          if(status.is(EOF)) cb(Success(null));
          else cb(Failure(UvError.ofStatus(status)));  
        } 
      }) {
        case 0:
        case code: cb(Failure(UvError.ofStatus(code)));
      }
    });
  }
  
  public function write(chunk:Chunk):Promise<Noise> {
    return Future.async(function(cb) {
      switch stream.write(chunk, function(status) cb(status.toErrorCode().toResult())) {
        case 0:
        case code: cb(Failure(UvError.ofStatus(code)));
      }
    });
  }
  
  public function shutdown():Promise<Noise> {
    return Future.async(function(cb) {
      switch stream.shutdown(function(status) cb(status.toErrorCode().toResult())) {
        case 0:
        case code: cb(Failure(UvError.ofStatus(code)));
      }
    });
  }
  
  public function close():Future<Noise> {
    stream.close(closedTrigger.trigger.bind(Noise));
    return closed;
  }
}