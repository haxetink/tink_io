package tink.io;

import haxe.io.*;
import tink.io.IdealSink;
import tink.io.IdealSource;
import tink.io.Pipe.PipeResult;
import tink.io.Source;

using tink.CoreApi;

@:forward
abstract Sink(SinkObject) to SinkObject from SinkObject {
  
  #if (nodejs && !macro)
  static public function ofNodeStream(name, w:js.node.stream.Writable.IWritable):Sink
    return new tink.io.nodejs.NodejsSink(w, name);
  #end
  
  public function writeFull(buffer:Buffer):Surprise<Bool, Error> {
    var self = this;//something weird is going on here with `this` being lost in the scope below
    return Future.async(function (cb) {
      function flush() {
        if (buffer.available == 0) 
          
          cb(Success(true));
          
        else 
          self.write(buffer).handle(function (o) switch o {
            
            case Success(p): 
              
              if (p.isEof)
                cb(Success(false));
              else
                flush();
                
            case Failure(e): 
              
              cb(Failure(e));
              
          });
      }
      
      flush();
    });    
  }
  
  static public function inMemory() 
    return ofOutput('Memory sink', new BytesOutput(), Worker.EAGER);
  
  static public function async(writer, closer):Sink
    return new AsyncSink(writer, closer);
    
  @:from static public function flatten(s:Surprise<Sink, Error>):Sink
    return new FutureSink(s);
  
  static public function ofOutput(name:String, target:Output, ?worker:Worker):Sink
    return new StdSink(name, target, worker);
  
  static public var stdout(default, null):Sink =
    #if (nodejs && !macro)
      ofNodeStream('stdout', js.Node.process.stdout)
    #elseif sys
      ofOutput('stdout', Sys.stdout())
    #else
      BlackHole.INST
    #end
  ;
}

class AsyncSink extends SinkBase {
  
  var closer:Void->Surprise<Noise, Error>;
  var closing:Surprise<Noise, Error>;
  var writer:Buffer->Surprise<Progress, Error>;
  var last:Surprise<Progress, Error>;
  
  public function new(writer, closer) {
    this.closer = closer;
    this.writer = writer;
    last = Future.sync(Success(Progress.NONE));
  }
  
  override public function write(from:Buffer) {
    if (closing != null)
      return Future.sync(Success(Progress.EOF));
    
    return cause(last = last >> function (p:Progress) {
      return writer(from);
    });
  }
  
  static function cause<A>(f:Future<A>) {
    f.handle(function () { } );
    return f;
  }
  
  override public function close() {
    if (closing == null) 
      cause(closing = last.flatMap(function (_) return closer()));
    
    return closing;
  }
}

class FutureSink extends SinkBase {
  var f:Surprise<Sink, Error>;
  
  public function new(f)
    this.f = f;
    
  static function cause<A>(f:Future<A>) {
    f.handle(function () { } );
    return f;
  }
    
  override public function write(from:Buffer):Surprise<Progress, Error> 
    return cause(f >> function (s:Sink) return s.write(from));
  
  override public function close() 
    return cause(f >> function (s:Sink) return s.close());
  
  public function toString() {
    var ret = 'PENDING';
    f.handle(function (o) ret = Std.string(o));
    return '[FutureSink $ret]';
  }  
}

class StdSink extends SinkBase {
  
  var name:String;
  var target:Output;
  var worker:Worker;  
  
  public function new(name, target, ?worker:Worker) {
    this.name = name;
    this.target = target;
    this.worker = worker.ensure();
  }
    
  override public function write(from:Buffer):Surprise<Progress, Error> 
    return 
      worker.work(
        function () return from.tryWritingTo(name, target)
      );
  
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
  
  public function toString() {
    return name;
  }
  
}

interface SinkObject {
  /**
   * Writes bytes to this sink.
   * Note that a Progress.EOF can mean two things:
   * 
   * - depletion of a readonly buffer, which is the case if `from.available == 0 && !from.writable`
   * - end of the sink itself
   */
  function write(from:Buffer):Surprise<Progress, Error>;
  /**
   * Ends the sink with the contents of the supplied buffer.
   * 
   * The default implementation will actually just use write and close, 
   * but some implementations may leverage pecularities of the underlying stream to optimize the procedure.
   * 
   * Note that if the sink ends on its own before all data is written, the buffer will contain any remaining data.
   */
  function finish(from:Buffer):Surprise<Noise, Error>;
  function close():Surprise<Noise, Error>;  
  function idealize(onError:Callback<Error>):IdealSink;
}

class SinkBase implements SinkObject {
  public function write(from:Buffer):Surprise<Progress, Error>
    return throw 'writing not implemented';
    
  public function finish(from:Buffer):Surprise<Noise, Error>
    return 
      Future.async(function (cb) {
        (this:Sink).writeFull(from).handle(function (o) switch o {
          case Success(true):
            close().handle(cb);
          case Success(false):
            cb(Success(Noise));
          case Failure(e): 
            cb(Failure(e));
        });
      });
    
  public function close():Surprise<Noise, Error>
    return Future.sync(Success(Noise));
    
  public function idealize(onError:Callback<Error>):IdealSink
    return new IdealizedSink(this, onError);
}

class ParserSink<T> extends SinkBase {
  
  var parser:StreamParser<T>;
  var state:Outcome<Progress, Error>;
  var onResult:T->Future<Bool>;
  var wait:Future<Bool>;
  var worker:Worker;
  static var idCounter = 0;
  var id:Int = idCounter++;
  var callCounter = 0;
  
  public function new(parser, onResult, ?worker:Worker) {
    this.parser = parser;
    this.onResult = onResult;
    this.wait = Future.sync(true);
    this.worker = Worker.EAGER;
  }
  
  function doClose()
    if (state == null)
      state = Success(Progress.EOF);
  
  override public function write(from:Buffer):Surprise<Progress, Error> {
    var call = callCounter++;
    return
      if (this.state != null)
        Future.sync(this.state);
      else
        this.wait.flatMap(function (resume) {
          return
            if (!resume) {
              doClose();
              Future.sync(this.state);
            }
            else 
              worker.work(function () {
                var last = from.available;
                return
                  if (last == 0 && !from.writable)
                    switch parser.eof() {
                      case Success(v):
                        doClose();
                        this.wait = onResult(v);//if it helps?
                        Success(Progress.EOF);
                      case Failure(e):
                        state = Failure(e);
                    }
                  else
                    switch parser.progress(from) {
                      case Success(d):
                        
                        switch d {
                          case Some(v):
                            this.wait = onResult(v);
                          case None:
                        }
                        
                        Success(Progress.by(last - from.available));
                        
                      case Failure(f):
                        state = Failure(f);
                    }
              });
        });
  }
  override public function close():Surprise<Noise, Error> {
    doClose();
    return Future.sync(Success(Noise));
  }
  
  public function parse(s:Source, ?options)
    return Future.async(function (cb:Outcome<Source, Error>->Void) {
      Pipe.make(s, this, Buffer.sufficientWidthFor(parser.minSize()), function (rest:Buffer, res:PipeResult<Error, Error>) 
        cb(switch res {
          case AllWritten:
            Success(s);
          case SinkEnded:
            Success(s.prepend((rest.content() : Source)));
          case SinkFailed(e):
            Failure(e);
          case SourceFailed(e):
            Failure(e);
        })
      );
    });
  
}
