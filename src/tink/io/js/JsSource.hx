package tink.io.js;

import tink.streams.Stream;
import tink.io.js.WrappedReadable;

using tink.CoreApi;

class JsSource extends Generator<Chunk, Error> {
	function new(target:WrappedReadable)
		super(Future.async(function(cb) {
			target.read().handle(function(o) cb(switch o {
				case Success(null): End;
				case Success(chunk): Link(chunk, new JsSource(target));
				case Failure(e): Fail(e);
			}));
		} #if !tink_core_2, true #end));

	static public function wrap(name, native, chunkSize, onEnd)
		return new JsSource(new WrappedReadable(name, native, chunkSize, onEnd));
}
