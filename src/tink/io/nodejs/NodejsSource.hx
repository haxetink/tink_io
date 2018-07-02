package tink.io.nodejs;

import tink.streams.Stream;

using tink.CoreApi;

class NodejsSource extends Generator<Chunk, Error> {
  
  function new(target:WrappedReadable) 
    super(Future.async(function (cb) {
      target.read().handle(function (o) cb(switch o {
        case Success(null): End;
        case Success(chunk): Link(chunk, new NodejsSource(target));
        case Failure(e): Fail(e);
      }));
    }, true));    
  
  static public function wrap(name, native, chunkSize, onEnd)
    return new NodejsSource(new WrappedReadable(name, native, chunkSize, onEnd));
  
}