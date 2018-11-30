package tink.io.uv;

import uv.Uv;
import cpp.*;
import haxe.io.*;
import tink.streams.Stream;

using tink.CoreApi;

class UvStreamSource extends Generator<Chunk, Error> {
  var name:String;
  var wrapper:UvStreamWrapper;
  
  public function new(name, wrapper) {
    this.name = name;
    this.wrapper = wrapper;
    super(Future.async(function(cb) {
      wrapper.read().handle(function(o) switch o {
        case Success(null): cb(End);
        case Success(chunk): cb(Link(chunk, new UvStreamSource(name, wrapper)));
        case Failure(e): cb(Fail(e));
      });
    }));
  }
}