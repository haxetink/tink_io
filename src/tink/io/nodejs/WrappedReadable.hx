package tink.io.nodejs;

import js.node.Buffer;
import js.node.stream.Readable.IReadable;
import tink.chunk.nodejs.BufferChunk;

using tink.CoreApi;

class WrappedReadable {

  var native:IReadable;
  var name:String;
  var end:Surprise<Null<Chunk>, Error>;
  var chunkSize:Int;
      
  public function new(name, native, chunkSize, onEnd) {
    this.name = name;
    this.native = native;
    this.chunkSize = chunkSize;
    end = Future.async(function (cb) {
      native.once('end', function () cb(Success(null)));
      native.once('error', function (e:{ code:String, message:String }) cb(Failure(new Error('${e.code} - Failed reading from $name because ${e.message}'))));      
    });
    if (onEnd != null)
      end.handle(function () 
        js.Node.process.nextTick(onEnd)
      );
  }

  public function read():Promise<Null<Chunk>>
    return Future.async(function (cb) {
      function attempt() {
        try 
          switch native.read(chunkSize) {
            case null:
              native.once('readable', attempt);
            case chunk:
              var buf:Buffer = 
                if (Std.is(chunk, String))
                  new Buffer((chunk:String))
                else
                  chunk;
                  
              cb(Success((new BufferChunk(buf) : Chunk)));
          }
        catch (e:Dynamic) {
          cb(Failure(Error.withData('Error while reading from $name', e)));
        }
      }
                    
      attempt();
      //end.handle(cb);
    }).first(end);
}