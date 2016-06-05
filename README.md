# Tink I/O - asynchronous I/O everywhere

This library provides a number of helpers for I/O:
 
- Progress - represents I/O progress
- Buffer - a circular buffer for binary data
- Worker - a lightweight abstraction of an I/O worker, which is compatible with tink.runloop.Worker
- Sink - an asynchronous output sink
- Source - an asynchronous input source
- IdealSource - an asynchronous input source that will not fail
- Pipe - can pipe a sink into a source
- StreamParser - used to parse sources

## Buffer

Buffers provide a relatively fat (for tink's standards) API to allow buffering binary data into `Bytes` working as [a circular buffer](https://en.wikipedia.org/wiki/Circular_buffer#How_it_works).

Buffer allocation is thread safe, buffer access is not. Try to keep a buffer on one thread only, if possible.

## StreamParser

StreamParsers are intended to parse data that they stream from buffers. Their interface is pretty simple:

```haxe
interface StreamParser<Result> {
	function progress(buffer:Buffer):Outcome<Option<Result>, Error>;
	function eof():Outcome<Result, Error>;
}
```

This reads from a buffer and optionally returns a result. The definition is simple, but implementing such a parser can be relatively tricky. Keep in mind that the parser may be run on some background thread, so avoid anything potentially not threadsafe. And also don't forget to reset the parser state when appropriate.

The simplest way to construct a parser is to subclass `tink.io.StreamParser.BytewiseParser` and override the `read` method. Note that EOF is denoted by `-1`.

## Sink

A sink is something you can write data to. Its interface is very simple:

```haxe
abstract Sink {
  function writeFull(buffer:Buffer):Surprise<Bool, Error>;
	function write(from:Buffer):Surprise<Progress, Error>;
	function close():Surprise<Noise, Error>;  
}
```

You can write data from a buffer and you can close it. Simples.

Sinks can represent output streams. They can also represent parsers, through `tink.io.Sink.ParserSink` which is an adapter from `StreamParser` to `Sink`.

## Source

A source is the counterpart of a sink. Sources come with a fleshed out interface:
  
```haxe
abstract Source {
	function read(into:Buffer):Surprise<Progress, Error>;
	function close():Surprise<Noise, Error>;
	function prepend(other:Source):Source;
	function append(other:Source):Source;
	function pipeTo(sink:Sink):Future<PipeResult>;
	function parse<T>(parser:StreamParser<T>):Surprise<{ data:T, rest: Source }, Error>;
	function parseWhile<T>(parser:StreamParser<T>, resume:T->Future<Bool>):Surprise<Source, Error>;
}
```

As you can see, the first two functions are the exact counterpart of sinks. Then there is more. 

Sources can be concatenated using `prepend` and `append`, they can be piped to sinks using `pipeTo` and they can be parsed with `parse` and `parseWhile`.

## IdealSource

Ideal sources are special sources, that do not fail.

```haxe
abstract IdealSource to Source {
	function readSafely(into:Buffer):Future<Progress>;
	function closeSafely():Future<Noise>;
}
```

For that reason, the base operations can be safely executed on them. The main point of ideal sources is to move responsibility for error handling to the call site. Imagine this:

```haxe
function respond(message:IdealSource):Future<Noise> { ... }
```

It is the callers responsibility to provide an ideal source. Ideal sources can be constructed in many ways. To construct them from (non-ideal) sources, one can either make a source that retries reading, or that just stops when it fails, or that exits the whole app. The caller chooses.

## Worker

Work, work, work! A worker looks like so:

```haxe
abstract Worker {
	public function work<A>(task:Lazy<A>):Future<A>;
	@:from static function ofRunLoopWorker(w:tink.runloop.Worker):Worker;
}
```

The most important bit is the `work` method which lazily executes a task and triggers the resulting future when ready. This can happen on a background thread. Usually you will not call this yourself. Instead, many sinks and sources (in particular `tink.io.Source.StdSource` and `tink.io.Sink.StdSink`) come with their own worker and execute their work on it. This ensures that work on such a sink or source is only carried out on one worker, thus avoiding a whole array of concurrency issues.

## Pipe

The pipe class provides the basic implementation for piping sources to sinks. There's not so much to be said about it.
