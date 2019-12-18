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

@:allow(tink.io.java)
class JavaFileSink extends SinkBase<Error, Noise> {
	static var handler = new WriteHandler();
	
	var name:String;
	var channel:AsynchronousFileChannel;
	var pos:Int;
	
	function new(name, channel, pos) {
		this.name = name;
		this.channel = channel;
		this.pos = pos;
	}
	
	override public function consume<EIn>(source:Stream<Chunk, EIn>, options:PipeOptions):Future<PipeResult<EIn, Error, Noise>> {
		var ret = source.forEach(function (c:Chunk) {
			return Future.async(function(cb:Callback<Handled<Error>>) {
				if(c.length == 0) {
					cb.invoke(Resume);
				} else {
					var ctx:WriteContext = {
						buffer: ByteBuffer.wrap(c.toBytes().getData()),
						cb: cb,
						name: name,
						pos: pos,
						total: c.length,
						channel: channel,
						written: 0,
					}
					channel.write(ctx.buffer, ctx.pos, ctx, handler);
					pos += c.length;
				}
			});
		});
			
		if (options.end)
			ret.handle(function (end) channel.close());
			
		return ret.map(function (c) return c.toResult(Noise));
	}
	
	static inline public function wrap(name, channel) {
		return new JavaFileSink(name, channel, 0);
	}
}
@:structInit
private class WriteContext {
	public var buffer:ByteBuffer;
	public var cb:Callback<Handled<Error>>;
	public var name:String;
	public var pos:Int;
	public var written:Int;
	public var total:Int;
	public var channel:AsynchronousFileChannel;
}

private class WriteHandler implements CompletionHandler<Integer, WriteContext>  {
	public function new() {}
	
	public function completed(result:Integer, ctx:WriteContext) {
		if((ctx.written += result.toInt()) < ctx.total)
			ctx.channel.write(ctx.buffer, ctx.pos + ctx.written, ctx, this);
		else
			ctx.cb.invoke(Resume);
	}
	
	public function failed(exc:Throwable, ctx:WriteContext) {
		ctx.cb.invoke(Clog(Error.withData('Write failed for "${ctx.name}", reason: ' + exc.getMessage(), exc)));
	}
}