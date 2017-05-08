package tink.io.std;

import haxe.io.*;
import tink.streams.Stream;
using tink.CoreApi;

class InputSource extends Generator<Chunk, Error> {
  public function new(name:String, target:Input, worker:Worker, buf:Bytes, offset:Int) {
    
    function next(buf, offset) 
      return new InputSource(name, target, worker, buf, offset);

    var free = buf.length - offset;

    super(Future.async(function (cb) {
      worker.work(function () {
        return try {
          var read = target.readBytes(buf, offset, free);
          
          if (read == 0) 
            Link(tink.Chunk.EMPTY, next(buf, offset));
          else {

            var nextOffset = 
              if (free - read < 0x400) 0;
              else offset + read;

            var nextBuf = 
              if (nextOffset == 0) Bytes.alloc(buf.length);
              else buf;

            Link(
              (buf:Chunk).slice(offset, offset + read),
              next(nextBuf, nextOffset)
            );
          }
        }
        catch (e:haxe.io.Eof) {
          End;
        }
        catch (e:haxe.io.Error) 
          switch e {
            case Blocked: 
              Link(tink.Chunk.EMPTY, next(buf, offset));
            #if (neko || cpp)
            case Custom(v) if(Std.string(v) == #if neko 'ssl@ssl_recv' #elseif cpp 'ssl_recv' #end):
              End; // FIXME: remove this case when issue resolved: https://github.com/HaxeFoundation/haxe/issues/6244
            #end
            default: 
              Fail(Error.withData('Failed to read from $name', e));
          }
      }).handle(function (step) {
        switch step {
          case End | Fail(_):
            try target.close()
            catch (e:Dynamic) {}
          default:
        }
        cb(step);
      });
    }, true));
  }
}