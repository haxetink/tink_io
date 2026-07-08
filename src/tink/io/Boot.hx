package tink.io;

#if macro
// this whole file existed because of https://github.com/HaxeFoundation/haxe/issues/12985
class Boot {
  static function boot() {
    tink.SyntaxHub.transformMain.whenever(function(e) {
      if (haxe.macro.Context.defined("java")) {
        return macro {
          @:pos(e.pos) tink.io.java.OnMainThread.init();
          $e;
        };
      } else {
        return e;
      }
    });
  }
}
#else
#error
#end