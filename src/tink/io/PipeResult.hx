package tink.io;

import tink.streams.Stream;

using tink.CoreApi;

enum PipeResult<In, Out, Result> {
  AllWritten:PipeResult<In, Out, Result>;
  SinkEnded(result:Result, rest:Source<In>):PipeResult<In, Out, Result>;
  SinkFailed(e:Error, rest:Source<In>):PipeResult<In, Error, Result>;
  SourceFailed(e:Error):PipeResult<Error, Out, Result>;
}

class PipeResultTools {
  
  /**
   * Transform PipeResult to an Outcome of the sink result
   */
  static public function toOutcome<EIn, FailingWith, Result>(result:PipeResult<EIn, FailingWith, Result>):Outcome<Option<Result>, Error> {
    return switch result {
      case AllWritten: Success(None);
      case SinkEnded(result, _): Success(Some(result));
      case SinkFailed(e, _) | SourceFailed(e): Failure(e);
    }
  }
  
  
  static public function toResult<EIn, FailingWith, Result>(c:Conclusion<Chunk, FailingWith, EIn>, result:Result, ?buffered:Chunk):PipeResult<EIn, FailingWith, Result> {

    function mk(s:Source<EIn>)
      return switch buffered {
        case null: s;
        case v: s.prepend(v);
      }

    return switch c {
      case Failed(e): SourceFailed(e);
      case Clogged(e, rest): SinkFailed(e, mk(rest));
      case Depleted: AllWritten;
      case Halted(rest): SinkEnded(result, mk(rest));      
    }
  }  
}