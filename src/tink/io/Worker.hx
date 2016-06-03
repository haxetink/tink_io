package tink.io;

using tink.CoreApi;

abstract Worker(WorkerObject) from WorkerObject to WorkerObject {
  
  static public var EAGER(default, null):Worker = new EagerWorker();
  static var pool:Array<Worker> = 
    #if (tink_runloop && !macro)
      [for (i in 0...#if concurrent 16 #else 1 #end) tink.RunLoop.current.createSlave()]
    #else
      [EAGER]
    #end
  ;
  
  public function ensure()
    return if (this == null) get() else this;
    
  static public function get() 
    return pool[Std.random(pool.length)];
    
  public function work<A>(task:Lazy<A>):Future<A>
    return this.work(task);
  
  #if (tink_runloop && !macro)
  @:from static function ofRunLoopWorker(worker):Worker
    return (new RunLoopWorker(worker) : WorkerObject);
  #end
}

private class EagerWorker implements WorkerObject {
  
  public function new() { }
  
  public function work<A>(task:Lazy<A>):Future<A>
    return Future.sync(task.get());    
}

#if (tink_runloop && !macro)
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