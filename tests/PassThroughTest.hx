package;

import tink.Chunk;
import tink.io.PassThrough;
import tink.streams.Stream;

using tink.io.Source;
using tink.CoreApi;

@:asserts
class PassThroughTest {
	public function new() {}
	
	public function ideal() {
		var pass = new PassThrough<Noise>();
		
		var data = [for(i in 0...4) (Std.string(i):Chunk)];
		var src:IdealSource = Stream.ofIterator(data.iterator());
		
		var total = 0;
		(pass:IdealSource).chunked()
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
			
		src.pipeTo(pass, {end: true}).eager();
		return asserts;
	}
	
	public function real() {
		var pass = new PassThrough<Error>();
		
		var data = [for(i in 0...4) (Std.string(i):Chunk)];
		var src:RealSource = Stream.ofIterator(data.iterator());
		
		var total = 0;
		(pass:RealSource).chunked()
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
			
		src.pipeTo(pass, {end: true}).eager();
		return asserts;
	}
}