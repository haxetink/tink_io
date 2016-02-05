package tink.io;

using tink.CoreApi;

abstract Worker(WorkerObject) from WorkerObject to WorkerObject {
  
  static public var EAGER(default, null):Worker = new EagerWorker();
  static public var DEFAULT(get, null):Worker;
    static function get_DEFAULT() {
      if (DEFAULT == null)
        DEFAULT =  
          #if tink_runloop
            new RunLoopWorkerPool(16);
          #else
            EAGER;
          #end
      return DEFAULT;
    }
  
  public inline function work<A>(task:Lazy<A>):Future<A>
    return 
      if (this == null) DEFAULT.work(task);
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
  var index = 0;
  public function new(size:Int) {
    this.workers = [for (i in 0...size) tink.RunLoop.current.createSlave()];
  }
  public function work<A>(task:Lazy<A>):Future<A> {
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