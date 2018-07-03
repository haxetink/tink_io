package;

import tink.io.Source;

using tink.CoreApi;

class Playground { 

  static function main() {
    var src:Source<NeverFails> = null;
    var sink:SinkProducing<String, NeverFails> = null;
    
    //sink.consume(src, Finish).handle(function (o) switch o {
    sink.consume(src, AndSeal).handle(function (o) switch o {
      //case SourceDepleted:
      case SinkEnded(_, _):
    });
  }
  
}

interface Source<FailingWith:PossibleError> { }

interface SinkProducing<Result, FailingWith:PossibleError> {
  function consume<In:PossibleError, Then>(s:Source<In>, ?andThen:AfterPiping<Then>):Future<PipeResult<In, FailingWith, Result, Then>>;
}

@:coreType abstract PossibleError {}
@:coreType abstract FailsWithError to PossibleError {}
@:coreType abstract NeverFails to PossibleError {}
@:coreType abstract SideEffect {}

enum AfterPiping<T> {
  AndSeal:AfterPiping<Sealed>;
  AndLeaveOpen:AfterPiping<LeftOpen>;
}

@:coreType abstract LeftOpen {}
@:coreType abstract Sealed {}


enum PipeResult<In:PossibleError, Out:PossibleError, Result, Then> {
  SourceDepleted:PipeResult<In, Out, Result, LeftOpen>;
  SinkEnded(result:Result, rest:Source<In>):PipeResult<In, Out, Result, Then>;
  SinkFailed(e:Error, rest:Source<In>):PipeResult<In, FailsWithError, Result, Then>;
  SourceFailed(e:Error):PipeResult<FailsWithError, Out, Result, Then>;
}
