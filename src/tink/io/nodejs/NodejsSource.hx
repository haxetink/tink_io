package tink.io.nodejs;

import tink.streams.Stream;

using tink.CoreApi;

class NodejsSource extends Chained<Chunk, Error> {
  
  function new(target:WrappedReadable) 
    super(target.read().map(function (o):Chain<Chunk, Error> return switch o {
      case Success(null): ChainEnd;
      case Success(chunk): ChainLink(chunk, new NodejsSource(target));
      case Failure(e): ChainError(e);
    }, true));
  
  static public function wrap(name, native, chunkSize)
    return new NodejsSource(new WrappedReadable(name, native, chunkSize));
  
}