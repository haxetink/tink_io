package;

import tink.io.StreamParser;

using tink.io.Source;
using tink.CoreApi;

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
	
	public function skip() {
		var s1:IdealSource = '01234';
		var s2:IdealSource = '56789';
		
		s1.append(s2).skip(3).all().handle(function(o) asserts.assert(o.toString() == '3456789'));
		s1.append(s2).skip(5).all().handle(function(o) asserts.assert(o.toString() == '56789'));
		s1.append(s2).skip(7).all().handle(function(o) asserts.assert(o.toString() == '789'));
		
		return asserts.done();
	}
	
	public function limit() {
		var s1:IdealSource = '01234';
		var s2:IdealSource = '56789';
		
		s1.append(s2).limit(3).all().handle(function(o) asserts.assert(o.toString() == '012'));
		s1.append(s2).limit(5).all().handle(function(o) asserts.assert(o.toString() == '01234'));
		s1.append(s2).limit(7).all().handle(function(o) asserts.assert(o.toString() == '0123456'));
		
		return asserts.done();
	}
	
	public function skipAndLimit() {
		var s1:IdealSource = '01234';
		var s2:IdealSource = '56789';
		
		s1.append(s2).skip(1).limit(3).all().handle(function(o) asserts.assert(o.toString() == '123'));
		s1.append(s2).skip(6).limit(3).all().handle(function(o) asserts.assert(o.toString() == '678'));
		s1.append(s2).skip(2).limit(6).all().handle(function(o) asserts.assert(o.toString() == '234567'));
		
		s1.append(s2).limit(4).skip(2).all().handle(function(o) asserts.assert(o.toString() == '23'));
		s1.append(s2).limit(8).skip(3).all().handle(function(o) asserts.assert(o.toString() == '34567'));
		s1.append(s2).limit(8).skip(6).all().handle(function(o) asserts.assert(o.toString() == '67'));
		
		return asserts.done();
	}
	
	public function split() {
		var s1:IdealSource = '01234';
		var s2:IdealSource = '56789';
		
		var split = s1.append(s2).split('45');
		split.before.all().handle(function(chunk) asserts.assert(chunk.toString() == '0123'));
		split.after.all().handle(function(chunk) asserts.assert(chunk.toString() == '6789'));
		split.delimiter.handle(function(o) asserts.assert(o.orNull() == '45'));
		
		return asserts.done();
	}
}