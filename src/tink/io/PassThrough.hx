package tink.io;

import tink.streams.Stream;
import tink.io.Sink;
import tink.io.Source;

using tink.io.PipeResult;
using tink.CoreApi;

class PassThrough<Quality> extends SignalStream<Chunk, Quality> implements SinkObject<Quality, Noise> implements SourceObject<Quality> {
  public var sealed(get, never):Bool;
    function get_sealed() return trigger == null;
    
  var trigger:SignalTrigger<Yield<Chunk, Quality>>;
    
  public function consume<EIn>(source:Stream<Chunk, EIn>, options:PipeOptions):Future<PipeResult<EIn, Quality, Noise>> {
    var ret = source.forEach(function(c:Chunk) {
      trigger.trigger(Data(c));
      return Resume;
    });
    
    if (options.end)
      ret.handle(function (end) {
        trigger.trigger(End);
        trigger = null;
      });
      
    return ret.map(function (c) {
      switch c {
        case Failed(e):
          trigger.trigger(cast Fail(e));
          trigger = null;
        case _:
      }
      return cast c.toResult(Noise);
    });
  }
  
  public function new() {
    super(trigger = Signal.trigger());
  }
}