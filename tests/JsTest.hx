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
		var source = Source.ofBlob('Blob', blob);
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
		var source = Source.ofBlob('Blob', blob, {chunkSize: 1});
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
}