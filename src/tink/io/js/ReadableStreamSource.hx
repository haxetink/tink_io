package tink.io.js;

import js.lib.Promise as JsPromise;
import js.lib.Uint8Array;
import tink.streams.Stream;

using tink.CoreApi;

typedef ReadableStreamReader = {
  function read():JsPromise<ReadableStreamReadResult>;
}

typedef ReadableStreamReadResult = {
  final done:Bool;
  final value:Null<Uint8Array>;
}

class ReadableStreamSource extends Generator<Chunk, Error> {
  var name:String;

  function new(name:String, reader:ReadableStreamReader) {
    this.name = name;

    super(Future.irreversible(function(cb) {
      reader.read().then(
        function(result) {
          if (result.done || result.value == null)
            cb(End);
          else {
            cb(Link((result.value : Chunk), new ReadableStreamSource(name, reader)));
          }
        },
        function(e) cb(Fail(Error.withData('Error reading from $name', e)))
      );
    }));
  }

  static public inline function wrap(name:String, stream:ReadableStream)
    return new ReadableStreamSource(name, stream.getReader());
}