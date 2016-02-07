package tink.io;

using tink.CoreApi;

abstract Worker(WorkerObject) from WorkerObject to WorkerObject {
  
  static public var EAGER(default, null):Worker = new EagerWorker();
  static public var DEFAULT(default, null):Worker =
    #if tink_runloop
      new RunLoopWorkerPool(16);
    #else
      EAGER;
    #end
    
  public function work<A>(task:Lazy<A>):Future<A>
    return 
      if (this == null) 
        Worker.DEFAULT.work(task);
      else this.work(task);
  
  #if tink_runloop
  @:from static function ofRunLoopWorker(worker):Worker
    return (new RunLoopWorker(worker) : WorkerObject);
  #end
}

private class EagerWorker implements WorkerObject {
  
  public function new() { }
  
  public function work<A>(task:Lazy<A>):Future<A>
    return Future.sync(task.get());    
}

#if tink_runloop
private class RunLoopWorkerPool implements WorkerObject {
  var workers:Array<tink.runloop.Worker>;
  var index:Int;
  
  public function new(size:Int)
    index = size;
  
  public function work<A>(task:Lazy<A>):Future<A> {
    if (workers == null)
      workers = [for (i in 0...index) tink.RunLoop.current.createSlave()];
    index = (index + 1) % workers.length;
    return 
      workers[0].owner.delegate(task, workers[index]);
  }
  
}
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