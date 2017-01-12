package tink.io.nodejs;

import js.node.Buffer;
import tink.io.Sink;
import tink.streams.Stream;
import tink.io.PipeResult;

using tink.CoreApi;

class NodejsSink extends SinkBase<Error> { 

  var target:WrappedWritable;
  
  function new(target) 
    this.target = target;
    
  override public function consume<EIn>(source:Stream<Chunk, EIn>, options:PipeOptions):Future<PipeResult<EIn, Error>> {
    
    //TODO: consider using native behavior is source is native and options.destructive is set to true
    
    var ret = source.forEach(function (c) 
      return target.write(c).map(function (w) return switch w {
        case Success(true): Resume;
        case Success(false): BackOff;
        case Failure(e): Fail(e);
      })
    );
    
    ret.handle(function (end) target.end());
    
    return ret.map(function (c):PipeResult<EIn, Error> return switch c {
      case Failed(e): SourceFailed(e);
      case Clogged(e, rest): SinkFailed(e, (rest : Source<EIn>));//TODO: somehow the implict conversion here will result in Source<Error> instead
      case Depleted: AllWritten;
      case Halted(rest): 
        SinkEnded((rest : Source<EIn>));
    });
  }
    
  static public function wrap(name, native)
    return new NodejsSink(new WrappedWritable(name, native));
    

}