package tink.io.java;

class OnMainThread {
  public static function run(fn:Void->Void):Void {
    #if haxe5
    haxe.EventLoop.main.run(fn);
    #else
    haxe.EntryPoint.runInMainThread(fn);
    #end
  }
}