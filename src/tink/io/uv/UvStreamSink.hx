package tink.io.uv;

import cpp.*;
import uv.Uv;
import tink.Chunk;
import tink.io.Sink;
import tink.streams.Stream;

using tink.io.PipeResult;
using tink.CoreApi;

class UvStreamSink extends SinkBase<Error, Noise> {
	
	var name:String;
	var handle:uv.Stream;
	
	public function new(name, handle) {
		this.name = name;
		this.handle = handle;
	}
	
	override public function consume<EIn>(source:Stream<Chunk, EIn>, options:PipeOptions):Future<PipeResult<EIn, Error, Noise>> {
		var ret = source.forEach(function (c:Chunk) {
			var trigger:FutureTrigger<Handled<Error>> = Future.trigger();
			var req = new uv.Write();
			var writeBuf = new uv.Buf(c.length);
			req.setData({
				buf: writeBuf,
				trigger: trigger,
			});
			writeBuf.copyFromBytes(c);
			handle.write(req, writeBuf, 1, Callable.fromStaticFunction(onWrite));
			return trigger.asFuture();
		});
			
		if (options.end)
			ret.handle(function (end) {
				if(!handle.asHandle().isClosing()) {
					handle.asHandle().close(Callable.fromStaticFunction(onClose));
					handle = null;
				}
			});
			
		return ret.map(function (c) return c.toResult(Noise));
	}
	
	static function onWrite(handle:RawPointer<Write_t>, status:Int) {
		var write:uv.Write = handle;
		var data:{buf:uv.Buf, trigger:FutureTrigger<Handled<Error>>} = write.getData();
		data.buf.destroy();
		write.destroy();
		data.trigger.trigger(status == 0 ? Resume : Clog(new Error(Uv.err_name(status))));
	}
	
	static function onClose(handle:RawPointer<Handle_t>) {
		uv.Stream.fromRawHandle(handle).destroy();
	}
}
