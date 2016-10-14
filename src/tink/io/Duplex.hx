package tink.io;

import tink.io.Source;
import tink.io.Sink;

interface Duplex {
	var source(get, never):Source;
	var sink(get, never):Sink;
	function close():Void;
}