package tink.io.cs;

import cs.system.io.Stream as CsStream;
import cs.system.AsyncCallback;
import tink.Chunk;
import tink.io.Sink;
import tink.streams.Stream;

using tink.io.PipeResult;
using tink.CoreApi;

class CsSink extends SinkBase<Error, Noise> {
	
	var name:String;
	var stream:CsStream;
	
	function new(name, stream) {
		this.name = name;
		this.stream = stream;
	}
	
	override public function consume<EIn>(source:Stream<Chunk, EIn>, options:PipeOptions):Future<PipeResult<EIn, Error, Noise>> {
		var ret = source.forEach(function (c:Chunk) {
			return Future.async(function(cb) {
				stream.BeginWrite(c.toBytes().getData(), 0, c.length, new AsyncCallback(function(ar) {
					stream.EndWrite(ar);
					cb((Resume:Handled<Error>));
				}), null);
			});
		});
			
		if (options.end)
			ret.handle(function (end) stream.Close());
			
		return ret.map(function (c) return c.toResult(Noise));
	}
	
	static inline public function wrap(name, stream)
		return new CsSink(name, stream);
}