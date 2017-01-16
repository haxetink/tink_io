package tink.io;

using tink.CoreApi;

enum PipeResult<In, Out, Result> {
  AllWritten:PipeResult<In, Out, Result>;
  SinkEnded(result:Result, rest:Source<In>):PipeResult<In, Out, Result>;
  SinkFailed(e:Error, rest:Source<In>):PipeResult<In, Error, Result>;
  SourceFailed(e:Error):PipeResult<Error, Out, Result>;
}