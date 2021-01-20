#if hxjs_http2
package tink.io.js;

import js.Stream;
import tink.chunk.ByteChunk;
import js.lib.*;

using tink.CoreApi;

class WrappedReadable {
	var native:ReadableStream;
	var name:String;
	var reader:ReadableStreamBYOBReader;
	var end:Surprise<Null<Chunk>, Error>;
	var _end:FutureTrigger<Outcome<Chunk, Error>>;
	var chunkSize:Int;

	public function new(name, native, chunkSize, onEnd) {
		this.name = name;
		this.native = native;
		this.reader = this.native.getReader({mode: "byob"});
		this.chunkSize = chunkSize;
		this.end = this._end = Future.trigger();
		if (onEnd != null)
			end.handle(function() haxe.Timer.delay(onEnd, 0));
	}

	public function read():Promise<Null<Chunk>>
		return Future.async(function(cb) {
			function attempt() {
				try {
					reader.read(new Uint8Array({})).then(function(r) {
						var chunk = r.value;
						var done = r.done;
						if (done) {
							this._end.trigger(Success(null));
						} else {
							cb(Success(ByteChunk.of(haxe.io.Bytes.ofData(chunk.buffer))));
						}
					});
				} catch (e:Dynamic) {
					cb(Failure(Error.withData('Error while reading from $name', e)));
				}
			}
			attempt();
		}).first(end);
}

#end