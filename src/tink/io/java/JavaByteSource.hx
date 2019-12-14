package tink.io.java;

import tink.streams.Stream;
import tink.Chunk;
import haxe.io.Bytes;
import java.lang.Integer;
import java.lang.Throwable;
import java.nio.channels.CompletionHandler;
import java.nio.channels.AsynchronousByteChannel;
import java.nio.ByteBuffer;

using tink.CoreApi;

@:allow(tink.io.java)
class JavaByteSource extends Generator<Chunk, Error> {
	var name:String;
	var channel:AsynchronousByteChannel;
	var size:Int;
	
	function new(name, channel, size) {
		this.name = name;
		this.channel = channel;
		this.size = size;
		
		super(Future.async(function(cb) {
			var buffer = ByteBuffer.allocate(size);
			channel.read(buffer, buffer, new ReadHandler(cb, this));
		}));
	}
	
	static inline public function wrap(name, stream, size) 
		return new JavaByteSource(name, stream, size);
}

private class ReadHandler implements CompletionHandler<Integer, ByteBuffer>  {
	var cb:Callback<Step<Chunk, Error>>;
	var parent:JavaByteSource;
	
	public function new(cb, parent) {
		this.cb = cb;
		this.parent = parent;
	}
	
	public function completed(result:Integer, buffer:ByteBuffer) {
		cb.invoke(
			if(result == -1)
				End
			else if(result == 0) {
				Link(Chunk.EMPTY, new JavaByteSource(parent.name, parent.channel, parent.size));
			} else {
				var len = result.toInt();
				var data = buffer.array();
				var chunk:Chunk = Bytes.ofData(data);
				var start = buffer.arrayOffset();
				Link(chunk.slice(start, start + len), new JavaByteSource(parent.name, parent.channel, parent.size));
			}
		);
	}
	
	public function failed(exc:Throwable, attachment:ByteBuffer) {
		cb.invoke(Fail(Error.withData('Read failed for "${parent.name}", reason: ' + exc.getMessage(), exc)));
	}
}