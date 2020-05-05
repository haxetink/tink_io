package;

import tink.Chunk;
import haxe.io.Bytes;

using tink.CoreApi;
using tink.io.Source;

@:asserts
class CastTest {
    public function new() {}
    
    @:variant(tink.Chunk.EMPTY)
    @:variant('')
    @:variant(haxe.io.Bytes.alloc(0))
    @:variant(tink.core.Future.sync(tink.Chunk.EMPTY))
    @:variant(tink.core.Future.sync(''))
    @:variant(tink.core.Future.sync(haxe.io.Bytes.alloc(0)))
    public function ideal(src:IdealSource) {
        src.all().next(v -> asserts.assert(v.length == 0)).handle(asserts.handle);
        return asserts;
    }

    
    @:variant(tink.Chunk.EMPTY)
    @:variant('')
    @:variant(haxe.io.Bytes.alloc(0))
    @:variant(tink.core.Future.sync(tink.Chunk.EMPTY))
    @:variant(tink.core.Future.sync(''))
    @:variant(tink.core.Future.sync(haxe.io.Bytes.alloc(0)))
    @:variant(tink.core.Promise.resolve(tink.Chunk.EMPTY))
    @:variant(tink.core.Promise.resolve(''))
    @:variant(tink.core.Promise.resolve(haxe.io.Bytes.alloc(0)))
    public function real(src:RealSource) {
        src.all().next(v -> asserts.assert(v.length == 0)).handle(asserts.handle);
        return asserts;
    }
}