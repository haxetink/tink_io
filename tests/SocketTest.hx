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
}
#end