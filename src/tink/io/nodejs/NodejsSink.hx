package tink.io.nodejs;

import tink.io.Buffer;
import tink.io.Sink;
using tink.CoreApi;

class NodejsSink extends SinkBase {
  
  var target:js.node.stream.Writable.IWritable;
  var name:String;
  var end:Surprise<Progress, Error>;
  
  public function new(target, name) {
    this.target = target;
    this.name = name;
    
    end = Future.async(function (cb) {
      target.once('end', function () cb(Success(Progress.EOF)));//mostly for 
      target.once('finish', function () cb(Success(Progress.EOF)));
      target.once('close', function () cb(Success(Progress.EOF)));
      target.once('error', function (e) cb(Failure(Error.reporter('Error while reading from $name')(e))));
    });
    end.handle(function (x) switch x {
      case Failure(e):
        trace(e.data);
      default:
    });
  }
  
  public function toString()
    return name;
  
  override public function write(from:Buffer):Surprise<Progress, Error> {
    return end || Future.async(function (cb) {
      var buf = null;
      
      var ret = from.writeTo({
        writeBytes: function (bytes, pos, len) {
          
          buf = js.node.Buffer.hxFromBytes(bytes).slice(pos, pos + len);
          return len;
        }
      });
      
      if (buf != null)
        target.write(buf, function () cb(Success(ret)));
      else
        cb(Success(ret));
    });
  }
  
  override public function finish(from:Buffer):Surprise<Noise, Error> {
    return Future.async(function (cb) {
      end.handle(function (o) switch o {
        case Success(_): cb(Success(Noise));
        case Failure(f): cb(Failure(f));
      });
      var onEnd = function () {
        from.clear();
        cb(Success(Noise));
      }
      switch from.content() {
        case content if(content.length == 0): target.end(onEnd);
        case content: target.end(js.node.Buffer.hxFromBytes(content), onEnd);
      }
    });
  }
    
  override public function close():Surprise<Noise, Error> 
    return 
      if (untyped target.writable == false) 
        Future.sync(Success(Noise));
      else 
        Future.async(function (cb) {
          target.end(function () {
            cb(Success(Noise));
          });
        });
    
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