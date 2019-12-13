package tink.io.cs;

import tink.streams.Stream;
import tink.Chunk;
import haxe.io.Bytes;
import cs.system.io.Stream as CsStream;
import cs.system.AsyncCallback;

using tink.CoreApi;

class CsSource extends Generator<Chunk, Error> {
	var name:String;
	
	function new(name, stream:CsStream, size:Int) {
		this.name = name;
		
		var buffer = new cs.NativeArray(size);
		super(Future.async(function(cb) {
			stream.BeginRead(buffer, 0, size, new AsyncCallback(function(ar) {
				cb(switch stream.EndRead(ar) {
					case 0: End;
					case read: 
						var chunk:Chunk = Bytes.ofData(buffer);
						Link(chunk.slice(0, read), new CsSource(name, stream, size));
				});
			}), null);
		}));
	}
	
	static inline public function wrap(name, stream, size) 
		return new CsSource(name, stream, size);
}