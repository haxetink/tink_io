package tink.io;

using tink.CoreApi;

abstract Worker(WorkerObject) from WorkerObject to WorkerObject {
  public inline function work<A>(task:Lazy<A>):Future<A> {
    if (this == null)
      this = DefaultWorker.INSTANCE;
    return this.work(task);
  }
  
  #if tink_runloop
  @:from static function ofRunLoopWorker(worker):Worker
    return (new RunLoopWorker(worker) : WorkerObject);
  #end
}

private class DefaultWorker implements WorkerObject {
  
  function new() { }
  
  public function work<A>(task:Lazy<A>):Future<A>
    return Future.sync(task.get());
    
  static public var INSTANCE(default, null):Lazy<Worker> = 
    #if tink_runloop
      function () return new RunLoopWorker(tink.RunLoop.current.createSlave()); 
    #else
      new DefaultWorker();
    #end
}

#if tink_runloop
private class RunLoopWorker implements WorkerObject {
  
  var actualWorker:tink.runloop.Worker;
  
  public function new(actualWorker)
    this.actualWorker = actualWorker;
  
  public function work<A>(task:Lazy<A>):Future<A> {
    return 
      actualWorker.owner.delegate(task, actualWorker);
  }
}
#end

interface WorkerObject {
  function work<A>(task:Lazy<A>):Future<A>;
}