package tink.io;

import haxe.io.*;

using tink.CoreApi;

@:forward
abstract Sink(SinkObject) to SinkObject from SinkObject {
  
  static public function ofOutput(name:String, target:Output, ?worker:Worker):Sink
    return new StdSink(name, target, worker);
    
}

class StdSink implements SinkObject {
  
  var name:String;
  var target:Output;
  var worker:Worker;  
  
  public function new(name, target, ?worker) {
    this.name = name;
    this.target = target;
    this.worker = worker;
  }
    
  public function write(from:Buffer):Surprise<Progress, Error>
    return worker.work(function () return from.tryWritingTo(name, target));
  
  public function close() {
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
	function close():Surprise<Noise, Error>;  
}