package;

import tink.io.StreamParser;
import tink.unit.Assert.*;

using tink.io.Source;
using tink.CoreApi;

@:asserts
class ParserTest {
	public function new() {}
	
	@:exclude
	@:describe('Should halt properly after consuming a result (issue #23)')
	public function properHalt() {
		var src:IdealSource = '1';
		return src.parse(new SimpleBytewiseParser(function(c) return if(c == -1) Progressed else Done(c)))
			.next(function(o) return assert(o.a == '1'.code));
	}
}