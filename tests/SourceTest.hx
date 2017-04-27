package;

import tink.io.StreamParser;
import tink.unit.Assert.*;
import tink.Chunk;

using tink.io.Source;
using tink.CoreApi;

@:asserts
class SourceTest {
	public function new() {}
	
	public function append() {
		var s1:IdealSource = '01234';
		var s2:IdealSource = '56789';
		
		s1.all().handle(function(chunk) asserts.assert(chunk == '01234'));
		s2.all().handle(function(chunk) asserts.assert(chunk == '56789'));
		s1.append(s2).all().handle(function(chunk) asserts.assert(chunk == '0123456789'));
		s2.append(s1).all().handle(function(chunk) asserts.assert(chunk == '5678901234'));
		
		return asserts.done();
	}
	
	public function prepend() {
		var s1:IdealSource = '01234';
		var s2:IdealSource = '56789';
		
		s1.all().handle(function(chunk) asserts.assert(chunk == '01234'));
		s2.all().handle(function(chunk) asserts.assert(chunk == '56789'));
		s1.prepend(s2).all().handle(function(chunk) asserts.assert(chunk == '5678901234'));
		s2.prepend(s1).all().handle(function(chunk) asserts.assert(chunk == '0123456789'));
		
		return asserts.done();
	}
	
	public function skip() {
		var s1:IdealSource = '01234';
		var s2:IdealSource = '56789';
		
		s1.append(s2).skip(3).all().handle(function(chunk) asserts.assert(chunk == '3456789'));
		s1.append(s2).skip(5).all().handle(function(chunk) asserts.assert(chunk == '56789'));
		s1.append(s2).skip(7).all().handle(function(chunk) asserts.assert(chunk == '789'));
		
		return asserts.done();
	}
	
	public function limit() {
		var s1:IdealSource = '01234';
		var s2:IdealSource = '56789';
		
		s1.append(s2).limit(3).all().handle(function(chunk) asserts.assert(chunk == '012'));
		s1.append(s2).limit(5).all().handle(function(chunk) asserts.assert(chunk == '01234'));
		s1.append(s2).limit(7).all().handle(function(chunk) asserts.assert(chunk == '0123456'));
		
		return asserts.done();
	}
	
	public function skipAndLimit() {
		var s1:IdealSource = '01234';
		var s2:IdealSource = '56789';
		
		s1.append(s2).skip(1).limit(3).all().handle(function(chunk) asserts.assert(chunk == '123'));
		s1.append(s2).skip(6).limit(3).all().handle(function(chunk) asserts.assert(chunk == '678'));
		s1.append(s2).skip(2).limit(6).all().handle(function(chunk) asserts.assert(chunk == '234567'));
		
		s1.append(s2).limit(4).skip(2).all().handle(function(chunk) asserts.assert(chunk == '23'));
		s1.append(s2).limit(8).skip(3).all().handle(function(chunk) asserts.assert(chunk == '34567'));
		s1.append(s2).limit(8).skip(6).all().handle(function(chunk) asserts.assert(chunk == '67'));
		
		return asserts.done();
	}
	
	public function split() {
		var s1:IdealSource = '01234';
		var s2:IdealSource = '56789';
		
		var split = s1.append(s2).split('45');
		split.before.all().handle(function(chunk) asserts.assert(chunk == '0123'));
		split.after.all().handle(function(chunk) asserts.assert(chunk == '6789'));
		split.delimiter.handle(function(o) asserts.assert(o.orUse(Chunk.EMPTY) == '45'));
		
		var s1:IdealSource = '12';
		var split = s1.split('2');
		split.before.all().handle(function(chunk) asserts.assert(chunk == '1'));
		split.after.all().handle(function(chunk) asserts.assert(chunk == ''));
		split.delimiter.handle(function(o) asserts.assert(o.orUse(Chunk.EMPTY) == '2'));
		
		var split = s1.split('1');
		split.before.all().handle(function(chunk) asserts.assert(chunk == ''));
		split.after.all().handle(function(chunk) asserts.assert(chunk == '2'));
		split.delimiter.handle(function(o) asserts.assert(o.orUse(Chunk.EMPTY) == '1'));
		
		var split = s1.split('3');
		split.before.all().handle(function(chunk) asserts.assert(chunk == '12'));
		split.after.all().handle(function(chunk) asserts.assert(chunk == ''));
		split.delimiter.handle(function(o) asserts.assert(o.orUse(Chunk.EMPTY) == ''));
		
		var s1:IdealSource = '12131415';
		var split = s1.split('1');
		split.before.all().handle(function(chunk) asserts.assert(chunk == ''));
		split.after.all().handle(function(chunk) asserts.assert(chunk == '2131415'));
		var split = split.after.split('1');
		split.before.all().handle(function(chunk) asserts.assert(chunk == '2'));
		split.after.all().handle(function(chunk) asserts.assert(chunk == '31415'));
		var split = split.after.split('1');
		split.before.all().handle(function(chunk) asserts.assert(chunk == '3'));
		split.after.all().handle(function(chunk) asserts.assert(chunk == '415'));
		var split = split.after.split('1');
		split.before.all().handle(function(chunk) asserts.assert(chunk == '4'));
		split.after.all().handle(function(chunk) asserts.assert(chunk == '5'));
		
		return asserts.done();
	}
	
	public function parseStream() {
		var s1:IdealSource = '01234';
		var stream = s1.parseStream(new SimpleBytewiseParser(function(c) return Done(c)));
		stream.collect().handle(function(o) switch o {
			case Success(items):
				asserts.assert(items.length == 6); // TODO: this probably should be 5
			case Failure(e):
				asserts.fail(e);
		});
		
		var s1:IdealSource = '012';
		var s2:IdealSource = '34';
		var stream = s1.append(s2).parseStream(new SimpleBytewiseParser(function(c) return Done(c)));
		stream.collect().handle(function(o) switch o {
			case Success(items):
				asserts.assert(items.length == 6); // TODO: this probably should be 5
			case Failure(e):
				asserts.fail(e);
		});
		
		return asserts.done();
	}
}