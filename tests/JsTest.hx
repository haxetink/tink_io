package;

import js.html.*;
import tink.streams.Stream;

using tink.CoreApi;
using tink.io.Source;

@:asserts
class JsTest {
	public function new() {}
	
	public function blob() {
		var blob = new Blob(['tink'], {type: 'text/plain'});
		var source = Source.ofJsBlob('Blob', blob);
		source.all()
			.next(function(chunk) {
				asserts.assert(chunk.length == 4);
				return Noise;
			})
			.handle(asserts.handle);
		return asserts;
	}
	
	public function chunk() {
		var blob = new Blob(['tink'], {type: 'text/plain'});
		var source = Source.ofJsBlob('Blob', blob, {chunkSize: 1});
		var total = 0;
		source.chunked()
			.forEach(function(chunk) {
				asserts.assert(chunk.length == 1);
				total += chunk.length;
				return Resume;
			})
			.map(function(_) {
				asserts.assert(total == 4);
				return Success(Noise);
			})
			.handle(asserts.handle);
		return asserts;
	}

	#if hxjs_http2
	public function sink() {
		var blob = new Blob(['tink'], {type: 'text/plain'});
		var source = Source.ofJsBlob('Blob', blob, {chunkSize: 1});
		var total = 0;

		var writable = new js.Stream.WritableStream(cast {
			write: function(_chunk:js.lib.ArrayBufferView, ?_):js.lib.Promise<Dynamic> {
				var chunk:tink.Chunk = _chunk;
				asserts.assert(chunk.length == 1);
				total += chunk.length;
				return null;
			},
			close: function(_):js.lib.Promise<Dynamic> {
				
				return null;
			}
		});

		var sink = tink.io.Sink.ofJsStream('writable-stream-sink', writable);
		source.pipeTo(sink).handle(_ -> {
			asserts.assert(total == 4);
			asserts.done();
		});
		return asserts;
	}
	#end
}