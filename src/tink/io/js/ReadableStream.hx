package tink.io.js;

// This type should be defined in js.lib or somewhere else
@:native('ReadableStream')
extern class ReadableStream {
  function getReader():ReadableStreamSource.ReadableStreamReader;
}