# Tinkerbell I/O

This library provides a few primitives for asynchronous I/O and various tools to operate on them as well as adapters to native I/O.

As a side note: If you are familiar with tink_streams you may find that some concepts documented there are reexplained here, simply to reduce the number of things required to understand this library.

## General Idea

Conceptually, `tink_io` revolves around the notion of sources and sinks:
  
- Sources are where data eminates from. You can think of them as `haxe.io.Input` or nodejs's `Readable`. In contrast to the former, they are asynchronous, in contrast to the latter, they are immutable - which means you can read the same data as many times as you want. 
- Sinks are the counterpart of sources, i.e. where data is sent to, although a more accurate definition is that a sink is something that can consume a Source and yield a result. Not all sinks have to yield meaningful results though. 

So an example of a source might be:
  
- data that is already in memory, such as a `String` or `tink.Chunk`
- the incoming stream of a TCP socket, the body of an HTTP message or a file opened for reading

The difference between the first kind of source and the second kind is, that attempting to read from the first will not cause errors, while reading from the second one may. We refer to them as *ideal* sources and *real* sources respectively.

A sink is everything that may consume a source:
  
- a buffer, into which we stream all data
- a streaming XML parser
- a file openened for writing

We see that sinks can also be categorized as *ideal* sinks and *real* sinks the same way we do it with sources. The first two examples are ideal (granted, writing to the standard output may fail, but for the sake of the argument let's pretend it won't). There is however one more quality of sinks that we distinguish them by: the type of result they produce (if any).

This means if we pipe data from a given source to a given sink, there's many possible outcomes, which depend strongly on the different qualities of either end. There are three ways to go about the problem:
  
1. Ignore it. Let the user keep track of the different possibilities. This is pretty much how nodejs does it. 
2. Have 4 classes of sinks with two methods each to consume one of the two types of sources we have.
3. Use type parameters to express the different qualities and then use GADTs to keep track of which outcomes we may have.

Unsurprisingly, `tink_io` explores the third approach, because it rather crushingly beats the first one in safety and the second one in code size. The price to pay is having to deal with a lot of type parameters. That may seem a little intimidating if you have only limited experience with it, but it is a skill well worth picking up, because it is an insanely powerful modeling tool that you can apply not only in all of your Haxe code, but even in the many other languages that decently support it.

## A very rough overview of the API

Let's express what we talked about above through code:

```haxe
//These types describe different error scenarios:
abstract PossibleError {}
abstract FailsWithError to PossibleError {}
abstract NeverFails to PossibleError {}

//And this one expresses the notion of side effects
abstract SideEffect {}

//A generic source:
abstract Source<FailingWith:PossibleError> { /* more this later */ }

//And the two variants of it:
typedef IdealSource = Source<NeverFails>;
typedef RealSource = Source<FailsWithError>;

//A generic sink
abstract SinkProducing<Result, FailingWith:PossibleError> { /* more on this rest later */ }

//And all the variants of it:
typedef Accumulator<Result> = SinkProducing<Result, NeverFails>; //can be "a buffer, into which we stream all data" 
typedef StreamParser<Result> = SinkProducing<Result, FailsWithError>;//can be "a streaming XML parser"
typedef RealSink = SinkProducing<SideEffect, FailsWithError>;//can be "a file opened for writing"
typedef IdealSink = SinkProducing<SideEffect, NeverFails>;//not actually mentioned in the examples above, but also has its place
```

This models exactly the different cases described just above. 

While all of this hopefully make sense, you might wonder how to actually *do* anything with this. So let's fill out a few of the blanks and look at the very core of the actual API:

```haxe
abstract Source<FailingWith:PossibleError> {
  var depleted(get, never):Bool;
  
  function pipeTo ...
  
  static public function empty<E:PossibleError>():Source<E>;
}

abstract SinkProducing<Result, FailingWith:PossibleError> { 
  var sealed(get, never):Bool;
  
  function consume<In:PossibleError, Then>(
      source:Source<In>, 
      andThen:AfterPiping<Then>
    ):Future<PipeResult<In, FailingWith, Result, Then>>;  
}

enum AfterPiping<T> {
  AndSeal:AfterPiping<Sealed>;
  AndLeaveOpen:AfterPiping<LeftOpen>;
}

abstract LeftOpen {}
abstract Sealed {}

enum PipeResult<In:PossibleError, Out:PossibleError, Result, Then> {
  SourceDepleted:PipeResult<In, Out, Result, LeftOpen>;
  SinkSealed(result:Result, rest:Source<In>):PipeResult<In, Out, Result, Then>;
  SinkFailed(e:Error, rest:Source<In>):PipeResult<In, FailsWithError, Result, Then>;
  SourceFailed(e:Error):PipeResult<FailsWithError, Out, Result, Then>;
}
```

For starters, let's understand that `source.pipeTo(sink)` is just a way of writing `sink.consume(source)` and you don't need to look at `pipeTo` at all - it exists primarily because `source -> dest` is largely considered more intuitive than `dest <- source`. Under the hood it is always the sink that consumes the source. That way the sink can naturally create back pressure.

Next, take note that a source may be `depleted` while a sink may be `sealed`. A source is depleted if it contains no data. A sink is depleted if it accepts no more data. Maybe because some size limit was reached, or because a parser found the end of the entity it is supposed to parse. Or because it was `sealed` manually, by calling `consume` or `pipeTo` with `AndSeal`.

It all comes together in `PipeResult`, a GADT which has *four* type parameters: one to describe the source, two to describe the sink and one to deal with whether or not it was the final pipe operation before sealing the sink. 

Before we go any deeper into the various outcomes, let's notice that unless the source is depleted or fails, the `PipeResult` contains a `rest`, i.e. the remaining data not consumed by the sink. The original source stays virtually unchanged (except that if the data was read for the first time, it is now in memory until the source gets garbage collected).

We see that in all combinations `SinkSealed` is included, because that is always a possibility: the sink can decide to finish by its self. It may also have been sealed before. Or it may be sealed because we're piping with `AndSeal`. Once a sink is sealed it produces its result and also gives us the remaining data. Note that the original source is left unmodified.

## Caveats

### Memory management

Because sources are immutable you need to be very conscious about any references to them that you might hold. If you pipe a source while holding a reference to it, then all data winds up in memory. If you wish to use reuse the data, this is perfect. If it was meant for single use, you're potentially wasting a lot of memory.

Let's look at the difference:
  
```haxe
var source:RealSource = ...;
var sink:RealSink = ...;

//this allows for memory to be freed:
source.pipeTo(sink).handle(function () {
  //by the time this callback is invoke `source` will already be garbage collected
});

//this prevents memory from being garbage collected:
source.pipeTo(sink).handle(function () {
  trace(source);//<-- this is the original source with all data in memory
});
```


### Performance

The memory efficiency of `tink_io` strongly depends on the garbage collection of the host runtime environment. There are plans to allow for manual memory management at the cost of sacrificying immutability.

Generally, a lot of benchmarking is to be done to further optimize `tink_io` but superficial tests on nodejs appear quite promising. Copying a 379MB tar file (containing the wonderful game Master of Orion 2) a 100 times by piping yields these results:
  
| Task (x100)                                         | Time taken  | Memory used (RSS) |
| --------------------------------------------------- | :---------: | :---------------: |
| native pipe                                         | TODO        | TODO              |
| tink_io pipe with 65K chunks                        | TODO        | TODO              |
| tink_io pipe with 1MB chunks                        | TODO        | TODO              |
| tink_io pipe with 65K chunks reusing the source     | TODO        | TODO              |
| tink_io pipe with 1MB chunks reusing the source     | TODO        | TODO              |

65K chunks are the default for nodejs which is presumably strongly tied to window size in TCP.


### Handling the `PipeResult`

It is crucial to handle the `PipeResult` and its error cases in particular. If you don't, errors may be silently swallowed. Also, some implementations may choose to return a lazy `Future` that does nothing at all unless you register a handler.
