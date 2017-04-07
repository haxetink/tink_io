package;

import haxe.Timer;
import js.node.Buffer;
import js.node.Fs;
import js.node.http.ServerResponse;
import tink.io.Source;
import tink.io.Sink;
//import tink.io.nodejs.NodejsFdStream;
import tink.io.nodejs.NodejsSink;
import haxe.unit.TestCase;
import haxe.unit.TestRunner;
import tink.io.nodejs.NodejsSource;
import tink.io.nodejs.WrappedBuffer;
import tink.io.nodejs.WrappedReadable;
import tink.io.nodejs.WrappedWritable;
import tink.streams.Stream;

import tink.Chunk;

import tink.io.StreamParser;

using tink.CoreApi;

class RunTests {
  
  static var cases:Array<Void->TestCase> = [
    
  ];
  static function main() {
    
    //var src = Source.ofNodeStream('some file', js.node.Fs.createReadStream('example.blob'), 0x100);
    //var copy = Sink.ofNodeStream('other file', js.node.Fs.createWriteStream('copy.blob'));
    //src.pipeTo(copy).handle(function (x) trace(x));
    //return;
    
    function repeat<X>(count, f:Void->Future<X>) 
      return Future.async(function (done) {
        var start = Timer.stamp();
        function loop(count) {
          if (count == 0) {
            done(Timer.stamp() - start);
          }
          else f().handle(loop.bind(count - 1));
        }
        loop(count);
      });
    
    //var file = 'bin/pureio.js';
    var file = 'example.blob';
    
    var chunkSize = 0x100000;
      
    //var f = Source.ofNodeStream('some file', js.node.Fs.createReadStream(file), chunkSize);
    var stat = Fs.statSync(file);
    js.node.Http.createServer(function (req, res:ServerResponse) {
      res.writeHead(200, 'ok', { 'content-length' : '' + stat.size } );
      
      js.node.Fs.createReadStream(file).pipe(res, { end: true } ); return;
      //f
      Source.ofNodeStream('some file', js.node.Fs.createReadStream(file), {chunkSize: chunkSize})
        .pipeTo(Sink.ofNodeStream('response body', res), { end: true });

    }).listen(2000);
    return;
    if (true) {
      repeat(100, function () {  
        var f = Source.ofNodeStream('some file', js.node.Fs.createReadStream(file), {chunkSize: chunkSize});
        //var f = new NodejsFdStream('some file', 
        var copy = Sink.ofNodeStream('other file', js.node.Fs.createWriteStream('copy.blob'));
        
        var ret = f.pipeTo(copy, { end: true } );
        //ret.handle(function (o) trace(o));
        return ret;
      }).handle(function (time) {
        trace('tink took $time');
        trace(js.Node.process.memoryUsage());
        //Timer.delay(function () { }, 10000);
      });
    }
    else
      repeat(100, function () {  
      
        var f = js.node.Fs.createReadStream('example.blob');
        var copy = js.node.Fs.createWriteStream('copy.blob');
        
        return Future.async(function (cb) f.pipe(copy, { end: true } ).on('finish', cb));
      }).handle(function (time) {
        trace('native took $time');
        trace(js.Node.process.memoryUsage());
        //Timer.delay(function () { }, 10000);
      });    
    
    //f.forEach(function (x:Chunk) {
      //js.Node.console.log('----------chunk:\n' + x);
      //return Promise.lift(true);
    //}).handle(function (e) trace(Std.string(e)));
    //var file = ;
    //var files:Array<Stream<Chunk>> = [for (i in 0...100) NodeSource.of(js.node.Fs.createReadStream('example.blob'))];
    //for (i in 0...1) {
      ////files.sort(function (_, _) return Std.random(3) - 1);
      //var compound = CompoundStream.of(files);
      //compound.forEach(function (x) {
        ////trace(x.length);
        //return true;
      //}).handle(function (x) {
        //trace(x);
      //});
    //}
    //
    return;
    
    var runner = new TestRunner();
    
    for (c in cases)
      runner.add(c());
    
    travix.Logger.exit(
      if (runner.run()) 0
      else 500
    );
  }
  
}

//interface IdealStreamObject {
  //function forEach<C>(c:Consumer<Chunk, C>):
//}
/*
typedef Split = {//TODO: make this @:structInit
  var left(default, null):Chunk;
  var right(default, null):Chunk;
  var next(default, null):Null<Splitter>;
}

typedef Splitter = Chunk->Bool->Split;

class Bissect<E> extends StreamBase<Chunk, E> {
  var splitter:Splitter;
  var target:Stream<Chunk, E>;
  var handleSubsequent:Stream<Chunk, E>->Void;
  
  function new(target, splitter, handleSubsequent) {
    this.target = target;
    this.splitter = splitter;
    this.handleSubsequent = handleSubsequent;
  }
  
  override public function forEach<C>(consume:Consumer<Chunk, C>):Result<Chunk, C, E> {
    
    var buf = Chunk.EMPTY,
        treat = splitter,
        end = null;
    
    return target.forEach(function (chunk:Chunk):Future<Step<C>> 
      return 
        switch treat(buf = buf.concat(chunk), false) {
          case fin if (fin.next == null):
            end = fin;
            Future.sync(Finish);
          case v:
            treat = v.next;
            consume(v.left).map(function (s):Step<C> return switch s {
              case BackOff:
                BackOff;
              case Finish:
                buf = v.right;
                Finish;
              case Resume:
                buf = v.right;
                Resume;
              case Fail(e):
                throw 'not implemented';
            });
        }
    ).map(function (o:End<Chunk, C, E>):End<Chunk, C, E> return switch [end, o] {
      case [null, Halted(rest)]:
        Halted(rest.prepend(new Single(buf)));
      //case [v, Halted(rest)]:
        
      //case Halted(rest):
        //if (end == null)
          
        //else
          //throw 'not implemented';
      //case Clogged(error, at):
        //throw 'not implemented';
      case [null, Failed(e)]: 
        handleSubsequent(cast Stream.ofError(e));//in this case we should actually know that `E` is `Error`, but apparently we don't
        o;
      case [null, Depleted]:
        handleSubsequent(Empty.make());
        o;
      default:
        throw 'assert';
    });
    
  }
  
  static public function make<E>(target:Stream<Chunk, E>, splitter) {
    var subsequent = Future.trigger();
    var ret = new Bissect(target, splitter, subsequent.trigger);
    return {
      first: ret,
      then: new FutureStream(subsequent.asFuture()),
    }
  }
}

class Limit<E> extends StreamBase<Chunk, E> {
  var target:Stream<Chunk, E>;
  var exceeded:Callback<Stream<Chunk, E>>;
  
  var limit:Int;
  
  function new(target, limit, exceeded) {
    this.target = target;
    this.limit = limit;
    this.exceeded = exceeded;
  }
  
  override public function forEach<C>(consume:Consumer<Chunk, C>):Result<Chunk, C, E> {
    var left = limit;
    var overflow:Stream<Chunk, E> = Empty.make();
    return target.forEach(function (chunk:Chunk):Future<Step<C>> {
      
      if (chunk.length > left) {
        overflow = cast new Single(chunk.slice(left, chunk.length));
        chunk = chunk.slice(0, left);
      }
        
      return consume(chunk).map(function (s:Step<C>):Step<C> return switch s {
        case Resume:
          left -= chunk.length;
          Resume;
        case v: 
          v;
      });
    }).map(function (res:End<Chunk, C, E>):End<Chunk, C, E> return switch res {
      case Halted(rest):
        Halted(
          if (left == 0)
            new Limit(rest, left, exceeded)
          else
            Empty.make()
        );
      case Clogged(_, _) | Failed(_) | Depleted:
        res;
    });
  }
  
  static public function on<E>(s:Stream<Chunk, E>, limit:Int) {
    //var trigger = Future.trigger();
    //var ret = new Limit(s, limit, trigger.trigger);
    //return {
      //excess: trigger.asFuture().
    //}
  }
}*/