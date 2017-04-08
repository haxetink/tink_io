package;

import tink.io.StreamParser;

using tink.io.Source;

@:asserts
class TestSource {
	public function new() {}
	
	public function append() {
		var s1:IdealSource = '01234';
		var s2:IdealSource = '56789';
		
		s1.all().handle(function(c) asserts.assert(c.toString() == '01234'));
		s2.all().handle(function(c) asserts.assert(c.toString() == '56789'));
		s1.append(s2).all().handle(function(c) asserts.assert(c.toString() == '0123456789'));
		s2.append(s1).all().handle(function(c) asserts.assert(c.toString() == '5678901234'));
		
		return asserts.done();
	}
	
	public function prepend() {
		var s1:IdealSource = '01234';
		var s2:IdealSource = '56789';
		
		s1.all().handle(function(c) asserts.assert(c.toString() == '01234'));
		s2.all().handle(function(c) asserts.assert(c.toString() == '56789'));
		s1.prepend(s2).all().handle(function(c) asserts.assert(c.toString() == '5678901234'));
		s2.prepend(s1).all().handle(function(c) asserts.assert(c.toString() == '0123456789'));
		
		return asserts.done();
	}
	
	public function parse() {
		var s1:IdealSource = '01234';
		var s2:IdealSource = '56789';
		
		s1.append(s2).parse(new Splitter('45')).handle(function(o) switch o {
			case Success(parsed):
				asserts.assert(parsed.a.toString() == '0123');
				parsed.b.all().handle(function(o) asserts.assert(o.toString() == '6789'));
			case Failure(e):
				asserts.fail(e);
		});
		return asserts.done();
	}
}