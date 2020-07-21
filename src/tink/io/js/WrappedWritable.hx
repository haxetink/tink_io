#if hxjs_http2
package tink.io.js;

import tink.Chunk;
import js.Stream;

using tink.CoreApi;

class WrappedWritable {
	var ended:Promise<Bool>;
	var _ended:PromiseTrigger<Bool>;
	var name:String;
	var native:WritableStream;
	var writer:WritableStreamDefaultWriter;

	public function new(name, native) {
		this.name = name;
		this.native = native;
		this.writer = this.native.getWriter();
		this._ended = Promise.trigger();
		this.ended = this._ended;
	}

	public function end():Promise<Bool> {
		var didEnd = false;

		ended.handle(function() didEnd = true).dissolve();

		if (didEnd)
			return false;
		function fail(e) {
			this._ended.trigger(Failure(e));
		}
		writer.close().then(function(_) {
			native.close().then(function(_) {
				_ended.trigger(Success(false));
			}).catchError(fail);
		}).catchError(fail);
		return ended.next(function(_) return true);
	}

	public function write(chunk:Chunk):Promise<Bool>
		return Future.async(function(cb) {
			if (chunk.length == 0) {
				cb(Success(true));
				return;
			}
			var buf = new js.lib.Uint8Array(chunk.toBytes().getData());
			writer.write(buf).then(function(_) {
				cb(Success(true));
			}).catchError(function(e) {
				cb(Failure(e));
			});
		}).first(ended);
}
#end