package tink.io.java;

import haxe.io.Bytes;
import java.lang.Integer;
import java.lang.Throwable;
import java.nio.channels.CompletionHandler;
import java.nio.channels.AsynchronousByteChannel;
import java.nio.ByteBuffer;
import tink.streams.Stream;
import tink.Chunk;
import tink.io.Sink;

using tink.io.PipeResult;
using tink.CoreApi;

@:allow(tink.io.java)
class JavaByteSink extends SinkBase<Error, Noise> {
	
	var name:String;
	var channel:AsynchronousByteChannel;
	
	function new(name, channel) {
		this.name = name;
		this.channel = channel;
	}
	
	override public function consume<EIn>(source:Stream<Chunk, EIn>, options:PipeOptions):Future<PipeResult<EIn, Error, Noise>> {
		var ret = source.forEach(function (c:Chunk) {
			return Future.async(function(cb:Callback<Handled<Error>>) {
				if(c.length == 0) {
					cb.invoke(Resume);
				} else {
					var buffer = ByteBuffer.wrap(c.toBytes().getData());
					channel.write(buffer, null, new WriteHandler(cb, this));
				}
			});
		});
			
		if (options.end)
			ret.handle(function (end) channel.close());
			
		return ret.map(function (c) return c.toResult(Noise));
	}
	
	static inline public function wrap(name, channel) {
		return new JavaByteSink(name, channel);
	}
}

private class WriteHandler implements CompletionHandler<Integer, Int>  {
	var cb:Callback<Handled<Error>>;
	var parent:JavaByteSink;
	
	public function new(cb, parent) {
		this.cb = cb;
		this.parent = parent;
	}
	
	public function completed(result:Integer, attachment:Int) {
		cb.invoke(Resume);
	}
	
	public function failed(exc:Throwable, attachment:Int) {
		cb.invoke(Clog(Error.withData('Write failed for "${parent.name}", reason: ' + exc.getMessage(), exc)));
	}
}