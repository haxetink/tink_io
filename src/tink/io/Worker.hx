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
    
  static public var INSTANCE(default, null):Worker = 
    #if tink_runloop
      new RunLoopWorker(null);
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
    var worker = 
      if (actualWorker != null) actualWorker;
      else tink.RunLoop.current;
      
    return 
      worker.owner.delegate(task, worker);
  }
}
#end

interface WorkerObject {
  function work<A>(task:Lazy<A>):Future<A>;
}