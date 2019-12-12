package tink.io.java;

import tink.streams.Stream;
import tink.Chunk;
import haxe.io.Bytes;
import java.lang.Integer;
import java.lang.Throwable;
import java.nio.channels.CompletionHandler;
import java.nio.channels.AsynchronousFileChannel;
import java.nio.ByteBuffer;

using tink.CoreApi;

@:allow(tink.io.java)
class JavaFileSource extends Generator<Chunk, Error> {
	var name:String;
	var channel:AsynchronousFileChannel;
	var pos:Int;
	var size:Int;
	
	function new(name, channel, pos, size) {
		this.name = name;
		this.channel = channel;
		this.pos = pos;
		this.size = size;
		
		super(Future.async(function(cb) {
			var buffer = ByteBuffer.allocate(size);
			channel.read(buffer, pos, buffer, new ReadHandler(cb, this));
		}));
	}
	
	static inline public function wrap(name, stream, size) 
		return new JavaFileSource(name, stream, 0, size);
}

private class ReadHandler implements CompletionHandler<Integer, ByteBuffer>  {
	var cb:Callback<Step<Chunk, Error>>;
	var parent:JavaFileSource;
	
	public function new(cb, parent) {
		this.cb = cb;
		this.parent = parent;
	}
	
	public function completed(result:Integer, buffer:ByteBuffer) {
		cb.invoke(
			if(result == -1)
				End
			else if(result == 0) {
				Link(Chunk.EMPTY, new JavaFileSource(parent.name, parent.channel, parent.pos, parent.size));
			} else {
				// TODO: maybe we don't need to do this memcpy
				var len = result.toInt();
				var data = new java.NativeArray(len);
				java.lang.System.arraycopy(buffer.array(), buffer.arrayOffset(), data, 0, len);
				Link((Bytes.ofData(data):Chunk), new JavaFileSource(parent.name, parent.channel, parent.pos + len, parent.size));
			}
		);
	}
	
	public function failed(exc:Throwable, attachment:ByteBuffer) {
		cb.invoke(Fail(Error.withData('Read failed for "${parent.name}", reason: ' + exc.getMessage(), exc)));
	}
}