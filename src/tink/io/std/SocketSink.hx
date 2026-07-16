package tink.io.std;

#if (sys && target.threaded)

import haxe.io.*;
import sys.net.Socket;
import tink.streams.Stream;

using tink.io.PipeResult;
using tink.CoreApi;

private enum WriteOutcome {
  Wrote(bytes:Int);
  Eof;
  WouldBlock;
  Failed(e:Error);
}

class SocketSink extends tink.io.Sink.SinkBase<Error, Noise> {
  var name:String;
  var socket:Socket;
  var pool:SelectPool;
  var worker:Worker;

  function new(name, socket, pool, worker) {
    this.name = name;
    this.socket = socket;
    this.pool = pool;
    this.worker = worker;
  }

  override public function consume<EIn>(source:Stream<Chunk, EIn>, options:PipeOptions):Future<PipeResult<EIn, Error, Noise>> {
    var rest = Chunk.EMPTY;

    var ret = source.forEach(function (c:Chunk) return Future.async(function (cb) {

      var pos = 0,
          bytes = c.toBytes();

      // Eager-first: attempt the write immediately and only fall back to the
      // select pool (and thus `Socket.select()`) once the socket reports
      // `Blocked`. This skips select entirely whenever the send buffer
      // already has room.
      function write() {
        if (pos == bytes.length) cb(Resume);
        else worker.work(function ():WriteOutcome {
          return try {
            Wrote(socket.output.writeBytes(bytes, pos, bytes.length - pos));
          }
          catch (e:haxe.io.Eof) {
            Eof;
          }
          catch (e:haxe.io.Error) switch e {
            case Blocked: WouldBlock;
            default: Failed(Error.withData('Error writing to $name', e));
          }
          catch (e:TypedError<Dynamic>) {
            Failed(cast e);
          }
          catch (e:Dynamic) {
            Failed(Error.withData('Error writing to $name', e));
          }
        }).handle(function (o) switch o {
          case Eof:
            rest = (bytes:Chunk).slice(pos, bytes.length);
            cb(Finish);
          case WouldBlock:
            pool.waitWritable(socket).handle(function (_) write());
          case Wrote(v):
            pos += v;
            if (pos == bytes.length) cb(Resume);
            else write();
          case Failed(e):
            cb(Clog(e));
        });
      }

      write();
    }));

    if (options.end)
      ret.handle(function (end) try socket.shutdown(false, true) catch (e:Dynamic) {});

    return ret.map(function (c) return c.toResult(Noise, rest));
  }

  static inline public function wrap(name:String, socket:Socket, pool:SelectPool, worker:Worker) {
    pool.register(socket);
    return new SocketSink(name, socket, pool, worker);
  }
}

#end
