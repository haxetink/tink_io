package tink.io.std;

#if (sys && target.threaded)

import haxe.io.*;
import sys.net.Socket;
import tink.streams.Stream;

using tink.CoreApi;

private enum ReadOutcome {
  Done(step:Step<Chunk, Error>);
  WouldBlock;
}

class SocketSource extends Generator<Chunk, Error> {
  public function new(name:String, socket:Socket, pool:SelectPool, worker:Worker, buf:Bytes, offset:Int) {

    function next(buf, offset)
      return new SocketSource(name, socket, pool, worker, buf, offset);

    var free = buf.length - offset;

    // Eager-first: attempt the read immediately and only fall back to the
    // select pool (and thus `Socket.select()`) once the socket reports
    // `Blocked`. This skips select entirely whenever data is already there.
    super(Future.async(function (cb) {
      function attempt()
        worker.work(function ():ReadOutcome {
          return try {
            var read = socket.input.readBytes(buf, offset, free);

            if (read == 0)
              Done(Link(tink.Chunk.EMPTY, next(buf, offset)));
            else {

              var nextOffset =
                if (free - read < 0x400) 0;
                else offset + read;

              var nextBuf =
                if (nextOffset == 0) Bytes.alloc(buf.length);
                else buf;

              Done(Link(
                (buf:Chunk).slice(offset, offset + read),
                next(nextBuf, nextOffset)
              ));
            }
          }
          catch (e:haxe.io.Eof) {
            Done(End);
          }
          catch (e:haxe.io.Error) switch e {
            case Blocked:
              WouldBlock;
            default:
              Done(Fail(Error.withData('Failed to read from $name', e)));
          }
        }).handle(function (outcome) switch outcome {
          case WouldBlock:
            pool.waitReadable(socket).handle(function (_) attempt());
          case Done(step):
            cb(step);
        });
      attempt();
    } #if !tink_core_2 , true #end));
  }

  static inline public function wrap(name:String, socket:Socket, pool:SelectPool, worker:Worker, size:Int) {
    pool.register(socket);
    return new SocketSource(name, socket, pool, worker, Bytes.alloc(size), 0);
  }
}

#end
