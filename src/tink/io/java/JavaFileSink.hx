package tink.io.java;

import haxe.io.Bytes;
import java.lang.Integer;
import java.lang.Throwable;
import java.nio.channels.CompletionHandler;
import java.nio.channels.AsynchronousFileChannel;
import java.nio.ByteBuffer;
import tink.streams.Stream;
import tink.Chunk;
import tink.io.Sink;

using tink.io.PipeResult;
using tink.CoreApi;

private typedef FileWriteContext = WriteContext<AsynchronousFileChannel>;

@:allow(tink.io.java)
class JavaFileSink extends SinkBase<Error, Noise> {
	
	var name:String;
	var channel:AsynchronousFileChannel;
	var handler = new WriteHandler();
	
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
					var ctx:FileWriteContext = {
						buffer: ByteBuffer.wrap(c.toBytes().getData()),
						cb: cb,
						name: name,
						total: c.length,
						channel: channel,
						written: 0,
					}
					channel.write(ctx.buffer, ctx.written, ctx, handler);
				}
			});
		});
			
		if (options.end)
			ret.handle(function (end) channel.close());
			
		return ret.map(function (c) return c.toResult(Noise));
	}
	
	static inline public function wrap(name, channel) {
		return new JavaFileSink(name, channel);
	}
}

private class WriteHandler implements CompletionHandler<Integer, FileWriteContext>  {
	public function new() {}
	
	public function completed(result:Integer, ctx:FileWriteContext) {
		if((ctx.written += result.toInt()) < ctx.total)
			ctx.channel.write(ctx.buffer, ctx.written, ctx, this);
		else
			ctx.cb.invoke(Resume);
	}
	
	public function failed(exc:Throwable, ctx:FileWriteContext) {
		ctx.cb.invoke(Clog(Error.withData('Write failed for "${ctx.name}", reason: ' + exc.getMessage(), exc)));
	}
}