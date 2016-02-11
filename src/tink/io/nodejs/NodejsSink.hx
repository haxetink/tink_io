package tink.io.nodejs;

import tink.io.Sink;
using tink.CoreApi;

class NodejsSink extends AsyncSink {
  var target:js.node.stream.Writable.IWritable;
  var name:String;
  public function new(target, name) {
    this.target = target;
    this.name = name;
    super(
      function (from:Buffer) { 
        var bytes = from.content();
        var progress = from.writeTo( { writeBytes: function (b, pos, len) return len } );
        var native = js.node.Buffer.hxFromBytes(bytes);
        return 
          if (progress.isEof || target.write(native)) 
            Future.sync(Success(progress));
          else
            Future.async(function (cb) 
              next({
                drain: function (_) cb(Success(progress)),
                error: function (e) cb(Failure(new Error('Failed writing to $name', e))),
              })
            );
      },
      function () {
        target.end();
        return Future.sync(Success(Noise));
      }
    );
  }
  
  public function toString()
    return name;
  
  function next(handlers:Dynamic<Dynamic->Void>) {
    
    var handlers:haxe.DynamicAccess<Dynamic->Void> = handlers;
    
    function removeAll() {
      for (key in handlers.keys())
        target.removeListener(key, handlers[key]);
    }
    
    for (key in handlers.keys()) {
      var old = handlers[key];
      var nu = handlers[key] = function (x) {
        old(x);
        removeAll();
      }
      target.addListener(key, nu);
    }
    
  }  
}