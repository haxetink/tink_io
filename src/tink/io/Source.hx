package tink.io;

import haxe.io.*;
import tink.io.Buffer;
import tink.io.IdealSink;
import tink.io.IdealSource;
import tink.io.Pipe;
import tink.io.Sink;
import tink.io.StreamParser;
import tink.io.Worker;
import tink.streams.*;
import haxe.ds.Option;

using tink.CoreApi;

abstract Source(SourceObject) from SourceObject to SourceObject {
  
  public inline function read(into:Buffer, max:Int = 1 << 30):Surprise<Progress, Error>
    return this.read(into, max);
    
  public inline function close():Surprise<Noise, Error>
    return this.close();
    
  public inline function all():Surprise<Bytes, Error> 
    return this.all();
  
  public inline function prepend(other:Source):Source
    return this.prepend(other);
  
  public inline function append(other:Source):Source
    return this.append(other);
  
  public inline function pipeTo<Out>(dest:PipePart<Out, Sink>, ?options: { ?end: Bool } ):Future<PipeResult<Error, Out>>
    return this.pipeTo(dest, options);
    
  public inline function idealize(onError:Callback<Error>):IdealSource
    return this.idealize(onError);
    
  public inline function parse<T>(parser:StreamParser<T>):Surprise<{ data:T, rest: Source }, Error>
    return this.parse(parser);
    
  public inline function parseWhile<T>(parser:StreamParser<T>, consumer:T->Future<Bool>):Surprise<Source, Error>
    return this.parseWhile(parser, consumer);
    
  public inline function parseStream<T>(parser:StreamParser<NullOr<T>>, ?rest:Callback<Source>):Stream<T>
    return this.parseStream(parser, rest);
     
  public inline function split(delim:Bytes):Pair<Source, Source>
    return this.split(delim);
  
  #if (nodejs && !macro)
  static public function ofNodeStream(name, r:js.node.stream.Readable.IReadable)
    return new tink.io.nodejs.NodejsSource(r, name);
  #end
  
  public function skip(length:Int):Source {
    return limit(length).pipeTo(BlackHole.INST).map(function(o) return switch o {
      case AllWritten: Success(this);
      case SourceFailed(e): Failure(e);
      default: Failure(new Error('assert')); // technically unreachable, the sink is ideal
    });
  }
  
  public function limit(length:Int):Source 
    return new LimitedSource(this, length);
  
  static public function async(f, close) 
    return new AsyncSource(f, close);
  
  @:from static public function failure(e:Error):Source
    return new FailedSource(e);
  
  static public function ofInput(name:String, input:Input, ?worker:Worker):Source
    return new StdSource(name, input, worker);
    
  @:from static public function flatten(s:Surprise<Source, Error>):Source
    return new FutureSource(s);    
    
  @:from static public function fromBytes(b:Bytes):Source
    return tink.io.IdealSource.ofBytes(b);
    
  @:from static public function fromString(s:String):Source
    return fromBytes(Bytes.ofString(s));
}

private class SimpleSource extends SourceBase {
  
  var closer:Void->Surprise<Noise, Error>;
  var reader:Buffer->Int->Surprise<Progress, Error>;
  
  public function new(reader, ?closer) {
    this.reader = reader;
    this.closer = closer;
  }
  
  override public function close():Surprise<Noise, Error> 
    return 
      if (this.closer == null) super.close();
      else closer();
  
  override public function read(into:Buffer, max = 1 << 30):Surprise<Progress, Error>
    return reader(into, max);
    
}

typedef NullOr<T> = T;//This is practically equivalent with Null<T>, except that it gets no special treatement by the compiler and just gets resolved to T. Otherwise it would fail for hxjava

interface SourceObject {
    
  function read(into:Buffer, max:Int = 1 << 30):Surprise<Progress, Error>;
  function close():Surprise<Noise, Error>;
  
  function all():Surprise<Bytes, Error>;
  
  function prepend(other:Source):Source;
  function append(other:Source):Source;
  function pipeTo<Out>(dest:PipePart<Out, Sink>, ?options:{ ?end: Bool }):Future<PipeResult<Error, Out>>;
  
  function idealize(onError:Callback<Error>):IdealSource;
  
  function parse<T>(parser:StreamParser<T>):Surprise<{ data:T, rest: Source }, Error>;
  function parseWhile<T>(parser:StreamParser<T>, cond:T->Future<Bool>):Surprise<Source, Error>;
  function parseStream<T>(parser:StreamParser<NullOr<T>>, ?rest:Callback<Source>):Stream<T>;
  function split(delim:Bytes):Pair<Source, Source>;
  
}

private class AsyncSource extends SourceBase {
  var data:SyntheticIdealSource;
  var end:Surprise<Noise, Error>;
  var onError:Surprise<Progress, Error>;
  var _close:Void->Void;
  
  public function new(f:SignalTrigger<Bytes>->FutureTrigger<Outcome<Noise, Error>>->Void, close) {
    this.data = IdealSource.create();
    _close = close;
    var onData = Signal.trigger(),
        onEnd = Future.trigger();
        
    onData.asSignal().handle(data.write);
    end = onEnd.asFuture();
    end.handle(function (e) {
      data.close();
    });
    onError = Future.async(function (cb) end.handle(function (o) switch o {
      case Failure(e): cb(Failure(e));
      default:
    }));
    f(onData, onEnd);
  }
    
  override public function read(into:Buffer, max = 1 << 30):Surprise<Progress, Error>
    return 
      data.read(into, max) || onError;
  
  override public function close():Surprise<Noise, Error> {
    _close();  
    return data.close();
  }

}

class SourceBase implements SourceObject {
  
  public function idealize(onError:Callback<Error>):IdealSource
    return new IdealizedSource(this, onError);
  
  public function prepend(other:Source):Source
    return CompoundSource.of(other, this);
    
  public function append(other:Source):Source
    return CompoundSource.of(this, other);
    
  public function read(into:Buffer, max = 1 << 30):Surprise<Progress, Error>
    return throw 'not implemented';
  
  public function close():Surprise<Noise, Error>
    return Future.sync(Success(Noise));
  
  public function pipeTo<Out>(dest:PipePart<Out, Sink>, ?options:{ ?end: Bool }):Future<PipeResult<Error, Out>>
    return Future.async(function (cb) Pipe.make(this, dest, options, function (_, res) cb(res)));
    
  public function all() {
    var out = new BytesOutput();
    return Future.async(function (cb) {
      pipeTo(Sink.ofOutput('memory buffer', out)).handle(function (r) cb(switch r {
        case SourceFailed(e): Failure(e);
        case AllWritten: Success(out.getBytes());
        default: throw 'assert';
      }));
    });
  }
  
    
  public function parse<T>(parser:StreamParser<T>):Surprise<{ data:T, rest: Source }, Error> {
    var ret = null;
    return 
      parseWhile(parser, function (x) { ret = x; return Future.sync(false); } ) 
      >> function (s:Source) return { data: ret, rest: s };
  }      
  
  public function parseWhile<T>(parser:StreamParser<T>, cond:T->Future<Bool>):Surprise<Source, Error>
    return new ParserSink(parser, cond).parse(this);
    
  public function parseStream<T>(parser:StreamParser<T>, ?rest:Callback<Source>):Stream<T>
    return new ParserStream(this, parser, rest);
    
  public function split(delim:Bytes):Pair<Source, Source> {
    //TODO: implement this in a streaming manner
    var f = parse(new Splitter(delim));
    return new Pair<Source, Source>(
      new FutureSource(f >> function (d:{ data: Bytes, rest: Source }) return (d.data : Source)),
      new FutureSource(f >> function (d:{ data: Bytes, rest: Source }) return d.rest)
    );
  }
}

private class ParserStream<T> extends tink.streams.Stream.StreamBase<T> {
  var source:Source;
  var parser:StreamParser<Null<T>>;
  var handleRest:Callback<Source>;
  
  public function new(source, parser, ?handleRest) {
    this.source = source;
    this.parser = parser;
    this.handleRest = handleRest;
  }
  
  override public function forEachAsync(item:T->Future<Bool>):Surprise<Bool, Error>
    return Future.async(function (finished) {
      var done = false;
      source.parseWhile(parser, function (v) 
        return if (v == null) {
          done = true;
          Future.sync(false);
        }
        else item(v)
      ).handle(function (o) finished(switch o {
        case Success(rest):
          if (done && handleRest != null)
            handleRest.invoke(rest);
          Success(done);
        case Failure(e): Failure(e);
      }));
    });
}

private class LimitedSource extends SourceBase {
  
  var limit:Int;
  var bytesRead = 0;
  var target:Source;
  var surplus = 0;
  
  public function new(target, limit) {
    this.target = target;
    this.limit = limit;
  }
  
  override public function read(into:Buffer, maxb:Int = 1 << 30):Surprise<Progress, Error> 
    return 
      if (bytesRead >= limit) 
        Future.sync(Success(Progress.EOF));
      else
        Future.async(function (cb) {
          if (maxb > limit - bytesRead)
            maxb = limit - bytesRead;
          target.read(into, maxb).handle(function (x) {
            switch x {
              case Success(p): bytesRead += p.bytes;
              default:
            }
            cb(x);
          });
        });
  
}

private class FutureSource extends SourceBase {
  
  var s:Surprise<Source, Error>;
  
  public function new(s)
    this.s = s;
    
  override public function read(into:Buffer, max = 1 << 30):Surprise<Progress, Error>
    return s >> function (s:Source) return s.read(into, max);
    
  override public function close():Surprise<Noise, Error>
    return s >> function (s:Source) return s.close();
  
  public function toString() {
    var ret = 'PENDING';
    s.handle(function (o) ret = Std.string(o));
    return '[FutureSource $ret]';
  }
    
}

private class FailedSource extends SourceBase {
  var error:Error;
  
  public function new(error)
    this.error = error;
    
  override public function read(into:Buffer, max = 1 << 30)
    return Future.sync(Failure(error));      
    
  override public function close() {
    return Future.sync(Failure(error));
  }
}

private class StdSource extends SourceBase {
  
  var name:String;
  var target:Input;
  var worker:Worker;
  
  public function new(name, target, ?worker:Worker) {
    this.name = name;
    this.target = target;
    this.worker = worker.ensure();
  }
    
  override public function read(into:Buffer, max = 1 << 30):Surprise<Progress, Error>
    return worker.work(function () return into.tryReadingFrom(name, target, max));
  
  override public function close() {
    return 
      worker.work(function () 
        return Error.catchExceptions(
          function () {
            target.close();
            return Noise;
          },
          Error.reporter('Failed to close $name')
        )
      );
  }
  override public function parseWhile<T>(parser:StreamParser<T>, cond:T->Future<Bool>):Surprise<Source, Error> {
    var buf = Buffer.alloc(Buffer.sufficientWidthFor(parser.minSize()));
    var ret = Future.async(function (cb) {
      function step(?noread)
        worker.work(function () return
          switch if (noread) Success(Progress.NONE) else buf.tryReadingFrom(name, target) {
            case Success(v):
              if (v.isEof)
                buf.seal();
              
              var available = buf.available;
              
              if (v.isEof && available == 0)
                parser.eof().map(Some);
              else
                switch parser.progress(buf) {
                  case Success(None) if (v.isEof && available == buf.available):
                    Failure(new Error('Parser hung on input'));
                  case v: v;
                }
            case Failure(e):
              Failure(e);
          }
        ).handle(function (o) switch o {
          case Failure(e): cb(Failure(e));
          case Success(Some(v)):
            cond(v).handle(function (v) 
              if (v) step(true);
              else cb(Success(this.prepend(buf.content())))
            );
          case Success(None): step();
        });
        
      step();
    });
    ret.handle(@:privateAccess buf.dispose);
    
    return ret;
  }  
  
  public function toString()
    return name;

}

private class CompoundSource extends SourceBase {
  var parts:Array<Source>;
  public function new(parts)
    this.parts = parts;
  
  override public function pipeTo<Out>(dest:PipePart<Out, Sink>, ?options:{ ?end: Bool }):Future<PipeResult<Error, Out>> 
    return Future.async(function (cb) {
      function next()
        switch parts {
          case []: cb(AllWritten);
          case v: 
            parts[0].pipeTo(dest, if (parts.length == 1) options else null).handle(function (x) switch x {
              case AllWritten:
                parts.shift().close();
                next();
              default:
                cb(x);
            });
        };
        
      next();
    });
  
  override public function close():Surprise<Noise, Error> {
    if (parts.length == 0) return Future.sync(Success(Noise));
    var ret = Future.ofMany([
      for (p in parts) 
        p.close()
    ]);
    parts = [];
    return ret.map(function (outcomes) {
      var failures = [];
      for (o in outcomes)
        switch o {
          case Failure(f):
            failures.push(f);
          default:
        }
      
      return switch failures {
        case []: 
          Success(Noise);
        default: 
          Failure(Error.withData('Error closing sources', failures));
      }
    });
  }
  
  override public function read(into:Buffer, max = 1 << 30):Surprise<Progress, Error>
    return switch parts {
      case []: 
        Future.sync(Success(Progress.EOF));
      default:
        parts[0].read(into).flatMap(
          function (o) return switch o {
            case Success(_.isEof => true):
              parts.shift().close();
              read(into, max);//Technically a huge array of empty synchronous sources could cause a stack overflow, but let's be optimistic for once!
            default:
              Future.sync(o);
          }
        );  
    }
  
  static public function of(a:Source, b:Source) //TODO: consider dealing with null
    return new CompoundSource(
      switch [Std.instance(a, CompoundSource), Std.instance(b, CompoundSource)] {
        case [null, null]: 
          [a, b];
        case [null, { parts: p }]: 
          [a].concat(p);  
        case [{ parts: p }, null]: 
          p.concat([b]);
        case [{ parts: p1 }, { parts: p2 }]:
          p1.concat(p2);
      }
    );
}