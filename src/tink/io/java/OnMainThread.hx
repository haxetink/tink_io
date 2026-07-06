package tink.io.java;

/**
  Java NIO async channel callbacks run on a JDK thread pool without a Haxe event loop.
  Re-dispatch stream completions so downstream code (e.g. haxe.Timer) runs on a safe thread.
**/
class OnMainThread {
	public static function run(fn:Void->Void):Void {
		#if tink_runloop
		tink.RunLoop.current.work(fn);
		#elseif java
		haxe.EntryPoint.runInMainThread(fn);
		#else
		fn();
		#end
	}
}
