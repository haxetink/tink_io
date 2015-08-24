package tink.io;

using tink.CoreApi;

@:forward
abstract Sink(SinkObject) to SinkObject from SinkObject {

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