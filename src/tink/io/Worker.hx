package tink.io;

using tink.CoreApi;

abstract Worker(WorkerObject) {
  public inline function work<A>(task:Lazy<A>):Future<A> {
    if (this == null)
      this = DefaultWorker.INSTANCE;
    return this.work(task);
  }
}

private class DefaultWorker implements WorkerObject {
  
  function new() { }
  
  public inline function work<A>(task:Lazy<A>):Future<A>
    return Future.sync(task.get());
    
  static public var INSTANCE(default, null):DefaultWorker;
}

interface WorkerObject {
  function work<A>(task:Lazy<A>):Future<A>;
}