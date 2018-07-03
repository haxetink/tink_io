package tink.io.std;

import haxe.io.*;
import tink.streams.Stream;

using tink.io.PipeResult;
using tink.CoreApi;

class OutputSink extends tink.io.Sink.SinkBase<Error, Noise> {
  var name:String;
  var target:Output;
  var worker:Worker;
  
  public function new(name, target, worker) {
    this.name = name;
    this.target = target;
    this.worker = worker;
  }

  override public function consume<EIn>(source:Stream<Chunk, EIn>, options:PipeOptions):Future<PipeResult<EIn, Error, Noise>> {
    var rest = Chunk.EMPTY;

    var ret = source.forEach(function (c:Chunk) return Future.async(function (cb) {
      
      var pos = 0,
          bytes = c.toBytes();

      function write() {
        if (pos == bytes.length) cb(Resume);
        else this.worker.work(
          function () 
            return try {
              Success(target.writeBytes(bytes, pos, bytes.length - pos));
            }
            catch (e:haxe.io.Eof) {
              Success(-1);
            }
            catch (e:haxe.io.Error) switch e {
              case Blocked: Success(0);
              default: Failure(Error.withData('Error writing to $name', e));
            }
            catch (e:Error) {
              Failure(e);
            }
            catch (e:Dynamic) {
              Failure(Error.withData('Error writing to $name', e));
            }
        ).handle(function (o) switch o {
          case Success(-1): 
            rest = (bytes:Chunk).slice(pos, bytes.length);
            cb(Finish);
          case Success(v):
            pos += v;
            if (pos == bytes.length) cb(Resume);
            else write();
          case Failure(e):
            cb(Clog(e)); 
        });
      }

      write();
    }));
    
    if (options.end)
      ret.handle(function (end) try target.close() catch (e:Dynamic) {});    
    
    return ret.map(function (c) return c.toResult(Noise, rest));    
  }
} 