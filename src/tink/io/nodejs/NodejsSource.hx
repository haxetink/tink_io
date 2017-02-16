package tink.io.nodejs;

import tink.streams.Stream;

using tink.CoreApi;

class NodejsSource extends Chained<Chunk, Error> {
  
  function new(target:WrappedReadable) 
    super(Future.async(function (cb) {
      target.read().handle(function (o) cb(switch o {
        case Success(null): ChainEnd;
        case Success(chunk): ChainLink(chunk, new NodejsSource(target));
        case Failure(e): ChainError(e);
      }));
    }, true));    
  
  static public function wrap(name, native, chunkSize, onEnd)
    return new NodejsSource(new WrappedReadable(name, native, chunkSize, onEnd));
  
}