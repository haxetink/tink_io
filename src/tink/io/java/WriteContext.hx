package tink.io.java;

import java.nio.ByteBuffer;
import tink.streams.Stream;

using tink.CoreApi;

@:structInit
class WriteContext<T> {
	public var buffer:ByteBuffer;
	public var cb:Callback<Handled<Error>>;
	public var name:String;
	public var written:Int;
	public var total:Int;
	public var channel:T;
}