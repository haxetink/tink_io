package tink.io.java;

class OnMainThread {
  public static function init() {
    run(noop);
  }

  public static function run(fn:Void->Void):Void {
    #if haxe5
    sys.thread.Thread.main().events.run(fn);
    #else
    haxe.EntryPoint.runInMainThread(fn);
    #end
  }

  static function noop() {}
}