package;
import tink.io.Worker.WorkerObject;

using tink.CoreApi;

class TestWorker implements WorkerObject {
  
  var queue:Array<Void->Void>;
  
  public function new() {
    this.queue = [];
  }
  
  public function work<A>(task:Lazy<A>):Future<A> {
    var t = Future.trigger();
    this.queue.push(function () t.trigger(task.get()));
    return t.asFuture();
  }
  
  public function run()
    return 
      switch queue.pop() {
        case null: false;
        case f: f(); true;
      }
  
      
  public function runAll()
    while (run()) {}
}