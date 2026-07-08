package;

#if (sys && target.threaded)
import sys.net.Socket;
import sys.net.Host;
import tink.io.Source;
import tink.io.Sink;
import tink.io.PipeResult;
import tink.io.std.SelectPool;

using tink.io.Source;
using tink.CoreApi;

@:asserts
@:timeout(15000)
class SocketTest {
  public function new() {}

  public function echo() {
    var pool = SelectPool.create();

    var server = new Socket();
    server.bind(new Host('127.0.0.1'), 0);
    server.listen(1);
    var port = server.host().port;

    var client = new Socket();
    client.connect(new Host('127.0.0.1'), port);

    var accepted = server.accept();
    server.close();

    var payload = 'hello from the select pool';
    for(i in 0...10) payload += payload;

    var src:IdealSource = payload;
    var dst = Sink.ofSocket('client sink', client, pool);

    src.pipeTo(dst, {end: true}).handle(function(o) {
      asserts.assert(o == AllWritten);
      var readBack = Source.ofSocket('accepted source', accepted, pool);
      readBack.all().handle(function(o) switch o {
        case Success(chunk):
          final ok = chunk == payload;
          asserts.assert(ok);
          accepted.close();
          pool.close();
          asserts.done();
        case Failure(e):
          asserts.fail(e);
      });
    });

    return asserts;
  }

  // Starting the read before any data has been sent forces the first read
  // attempt to hit `Blocked`, which routes it through `pool.waitReadable()`
  // and thus `Socket.select()` (unlike `echo()`, where the payload is
  // already fully written by the time the read starts).
  public function readWaitsForData() {
    var pool = SelectPool.create();

    var server = new Socket();
    server.bind(new Host('127.0.0.1'), 0);
    server.listen(1);
    var port = server.host().port;

    var client = new Socket();
    client.connect(new Host('127.0.0.1'), port);

    var accepted = server.accept();
    server.close();

    var payload = 'data sent only after the reader is already blocked on select()';

    var readBack = Source.ofSocket('accepted source', accepted, pool);
    readBack.all().handle(function(o) switch o {
      case Success(chunk):
        asserts.assert(chunk == payload);
        asserts.assert(pool.waitReadableCount() > 0);
        asserts.assert(pool.selectCallCount() > 0);
        client.close();
        pool.close();
        asserts.done();
      case Failure(e):
        asserts.fail(e);
    });

    var src:IdealSource = payload;
    var dst = Sink.ofSocket('client sink', client, pool);
    src.pipeTo(dst, {end: true}).handle(function(_) {});

    return asserts;
  }

  // Flooding a peer that isn't draining yet forces the write to fill the
  // send/receive buffers and hit `Blocked`, which routes it through
  // `pool.waitWritable()` and thus `Socket.select()`.
  public function writeWaitsForDrain() {
    var pool = SelectPool.create();

    var server = new Socket();
    server.bind(new Host('127.0.0.1'), 0);
    server.listen(1);
    var port = server.host().port;

    var client = new Socket();
    client.connect(new Host('127.0.0.1'), port);

    var accepted = server.accept();
    server.close();

    var payload = 'x';
    for(i in 0...23) payload += payload; // ~8MB, comfortably larger than OS socket buffers

    var src:IdealSource = payload;
    var dst = Sink.ofSocket('client sink', client, pool);

    src.pipeTo(dst, {end: true}).handle(function(o) {
      asserts.assert(o == AllWritten);
    });

    // Draining is only started after the write above, so it has to fill the
    // buffers and register with the select pool before any bytes are consumed.
    var readBack = Source.ofSocket('accepted source', accepted, pool);
    readBack.all().handle(function(o) switch o {
      case Success(chunk):
        asserts.assert(chunk.length == payload.length);
        asserts.assert(pool.waitWritableCount() > 0);
        asserts.assert(pool.selectCallCount() > 0);
        accepted.close();
        pool.close();
        asserts.done();
      case Failure(e):
        asserts.fail(e);
    });

    return asserts;
  }
}
#end
