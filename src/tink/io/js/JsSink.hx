package tink.io.js;

import tink.io.Sink;
import tink.streams.Stream;
import tink.io.js.WrappedWritable;
using tink.io.PipeResult;
using tink.CoreApi;

class JsSink extends SinkBase<Error, Noise> { 

  var target:WrappedWritable;
  
  function new(target) 
    this.target = target;
    
  override public function consume<EIn>(source:Stream<Chunk, EIn>, options:PipeOptions):Future<PipeResult<EIn, Error, Noise>> {
    
    //TODO: consider using native behavior is source is native and options.destructive is set to true
    
    var ret = source.forEach(function (c) 
      return target.write(c).map(function (w) return switch w {
        case Success(true): Resume;
        case Success(false): BackOff;
        case Failure(e): Clog(e);
      })
    );
    
    if (options.end)
      ret.handle(function (end) target.end());
    
    return ret.map(function (c) return c.toResult(Noise));
  }
    
  static public function wrap(name, native)
    return new JsSink(new WrappedWritable(name, native));
    

}