package tink.io.js;

import haxe.io.Bytes;
import js.html.*;
import tink.streams.Stream;

using tink.CoreApi;

class BlobSource extends Generator<Chunk, Error> {
  var name:String;
  
  function new(name:String, blob:Blob, pos:Int, chunkSize:Int) {
    this.name = name;
    
    super(Future.async(function (cb) {
      if(pos >= blob.size) {
        cb(End);
      } else {
        var end = pos + chunkSize;
        if(end > blob.size) end = blob.size;
        
        var reader = new FileReader();
        reader.onload = function() {
          var chunk:Chunk = Bytes.ofData(reader.result);
          cb(Link(chunk, new BlobSource(name, blob, end, chunkSize)));
        }
        reader.onerror = function(e:js.Error) cb(Fail(Error.ofJsError(e)));
        reader.readAsArrayBuffer(blob.slice(pos, end));
      }
    }, true));
  }
  
  static inline public function wrap(name, blob, chunkSize)
    return new BlobSource(name, blob, 0, chunkSize);
  
}