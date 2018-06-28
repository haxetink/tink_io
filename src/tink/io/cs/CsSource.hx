package tink.io.cs;

import tink.streams.Stream;
import tink.Chunk;
import haxe.io.Bytes;
import cs.system.io.Stream as CsStream;
import cs.system.AsyncCallback;

using tink.CoreApi;

class CsSource extends Generator<Chunk, Error> {
	function new(stream:CsStream, size:Int = 1024) {
		var buffer = new cs.NativeArray(size);
		super(Future.async(function(cb) {
			stream.BeginRead(buffer, 0, size, new AsyncCallback(function(ar) {
				cb(switch stream.EndRead(ar) {
					case 0: End;
					case read: 
						var buffer = if(read < size) {
							var copy = new cs.NativeArray(read);
							cs.system.Array.Copy(buffer, 0, copy, 0, read);
							copy;
						} else {
							buffer;
						}
						Link((Bytes.ofData(buffer):Chunk), new CsSource(stream, size));
				});
			}), null);
		}));
	}
	
	static public function wrap(stream:CsStream, size:Int = 1024) 
		return new CsSource(stream, size);
}