package tink.io;

using tink.CoreApi;

enum PipeResult<In, Out> {
  AllWritten:PipeResult<In, Out>;
  SinkFailed(e:Error, rest:Source<In>):PipeResult<In, Error>;
  SinkEnded(rest:Source<In>):PipeResult<In, Error>;
  SourceFailed(e:Error):PipeResult<Error, Out>;
}