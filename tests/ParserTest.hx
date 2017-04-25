package;

import tink.io.StreamParser;
import tink.Chunk;
import tink.unit.Assert.*;

using tink.io.Source;
using tink.CoreApi;

@:asserts
class ParserTest {
	public function new() {}
	
	@:describe('Should halt properly after consuming a result (issue #23)')
	public function properHalt() {
		var src:IdealSource = '1';
		return src.parse(new DummyParser()).next(function(o) return assert(o.a == '1'.code));
	}
}

class DummyParser extends BytewiseParser<Int> {
	public function new() {}
	override function read(c:Int) {
		return if(c == -1) Progressed else Done(c);
	}
}