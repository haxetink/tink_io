package tink.io;

import tink.Chunk.ChunkCursor;
import tink.io.PipeOptions;
import tink.io.Sink;
import tink.streams.Stream;

using tink.CoreApi;

enum ParseStep<Result> {
  Progressed;
  Done(r:Result);
  Failed(e:Error);
}

class BytewiseParser<Result> implements StreamParser<Result> { 

  function read(char:Int):ParseStep<Result> {
    return throw 'abstract';
  }
  
  
  public function progress(cursor:ChunkCursor) {
    
    do switch read(cursor.currentByte) {
      case Progressed:
      case Done(r): 
        cursor.next();
        return Done(r);
      case Failed(e):
        return Failed(e);
    } while (cursor.next());
    
    return Progressed;
  }
  
  public function eof(rest:ChunkCursor) 
    return switch read( -1) {
      case Progressed: Failure(new Error(UnprocessableEntity, 'Unexpected end of input'));
      case Done(r): Success(r);
      case Failed(e): Failure(e);
    }
  
  
}

interface StreamParser<Result> {
  function progress(cursor:ChunkCursor):ParseStep<Result>;
  function eof(rest:ChunkCursor):Outcome<Result, Error>;
}

//class ParserSink<T> extends SinkBase<Error> {
  //var parser:StreamParser<T>;
  //override public function consume<EIn>(source:Stream<Chunk, EIn>, options:PipeOptions):Future<PipeResult<EIn, Error>> {
    //var cursor = Chunk.EMPTY.cursor();
    //
    //var ret = source.forEach(function (chunk) {
      //
      //cursor.shift(chunk);
      //
      //switch parser.progress(cursor) {
        //case Progressed: 
          //return Future.sync(Resume);
        //case Done(v): 
          //return Future.sync(Finish);
        //case Failed(e): 
          //return Future.sync(Fail(e));
      //}
    //});
    //return null;
    ////return super.consume(source, options);
  //}
  //
//}

//class ParserSink<T> extends SinkBase {
  //
  //var parser:StreamParser<T>;
  //var state:Outcome<Progress, Error>;
  //var onResult:T->Future<Bool>;
  //var wait:Future<Bool>;
  //var worker:Worker;
  //static var idCounter = 0;
  //var id:Int = idCounter++;
  //var callCounter = 0;
  //
  //public function new(parser, onResult, ?worker:Worker) {
    //this.parser = parser;
    //this.onResult = onResult;
    //this.wait = Future.sync(true);
    //this.worker = Worker.EAGER;
  //}
  //
  //function doClose()
    //if (state == null)
      //state = Success(Progress.EOF);
  //
  //override public function write(from:Buffer):Surprise<Progress, Error> {
    //var call = callCounter++;
    //return
      //if (this.state != null)
        //Future.sync(this.state);
      //else
        //this.wait.flatMap(function (resume) {
          //return
            //if (!resume) {
              //doClose();
              //Future.sync(this.state);
            //}
            //else 
              //worker.work(function () {
                //var last = from.available;
                //return
                  //if (last == 0 && !from.writable)
                    //switch parser.eof() {
                      //case Success(v):
                        //doClose();
                        //this.wait = onResult(v);//if it helps?
                        //Success(Progress.EOF);
                      //case Failure(e):
                        //state = Failure(e);
                    //}
                  //else
                    //switch parser.progress(from) {
                      //case Success(d):
                        //
                        //switch d {
                          //case Some(v):
                            //this.wait = onResult(v);
                          //case None:
                        //}
                        //
                        //Success(Progress.by(last - from.available));
                        //
                      //case Failure(f):
                        //state = Failure(f);
                    //}
              //});
        //});
  //}
  //override public function close():Surprise<Noise, Error> {
    //doClose();
    //return Future.sync(Success(Noise));
  //}
  //
  //public function parse(s:Source, ?options)
    //return Future.async(function (cb:Outcome<Source, Error>->Void) {
      //Pipe.make(s, this, Buffer.sufficientWidthFor(parser.minSize()), function (rest:Buffer, res:PipeResult<Error, Error>) 
        //cb(switch res {
          //case AllWritten:
            //Success(s);
          //case SinkEnded:
            //Success(s.prepend((rest.content() : Source)));
          //case SinkFailed(e):
            //Failure(e);
          //case SourceFailed(e):
            //Failure(e);
        //})
      //);
    //});
  //
//}
//