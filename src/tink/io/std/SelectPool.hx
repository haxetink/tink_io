package tink.io.std;

#if (sys && target.threaded)

import sys.net.Socket;
import sys.thread.Thread;
import sys.thread.Mutex;
import sys.thread.Lock;
import haxe.ds.ObjectMap;

using tink.CoreApi;

/**
 * Multiplexes readiness of `sys.net.Socket`s across a single dedicated thread
 * running `Socket.select()`, so `SocketSource`/`SocketSink` can wait for a
 * socket to become readable/writable without dedicating a thread per socket.
 */
abstract SelectPool(SelectPoolObject) from SelectPoolObject to SelectPoolObject {

  /**
   * Registers a socket with this pool, switching it to non-blocking mode.
   * Idempotent: safe (and cheap) to call more than once for the same socket.
   */
  public function register(socket:Socket):Void
    this.register(socket);

  public function waitReadable(socket:Socket):Future<Noise>
    return this.wait(socket, true);

  public function waitWritable(socket:Socket):Future<Noise>
    return this.wait(socket, false);

  /**
   * Stops the select thread. Any waiters still pending are woken so they can
   * observe the socket failing on their next I/O attempt.
   */
  public function close():Void
    this.close();

  #if test
  /**
   * Test-only introspection into how often this pool actually fell back to
   * `Socket.select()`, as opposed to resolving I/O eagerly.
   */
  public function waitReadableCount():Int
    return this.waitReadableCount();

  public function waitWritableCount():Int
    return this.waitWritableCount();

  public function selectCallCount():Int
    return this.selectCallCount();
  #end

  static public function create(?name:String, ?worker:Worker):SelectPool
    return (new SelectPoolImpl(name, worker) : SelectPoolObject);
}

interface SelectPoolObject {
  function register(socket:Socket):Void;
  function wait(socket:Socket, read:Bool):Future<Noise>;
  function close():Void;
  #if test
  function waitReadableCount():Int;
  function waitWritableCount():Int;
  function selectCallCount():Int;
  #end
}

private class SelectPoolImpl implements SelectPoolObject {

  var name:String;
  var worker:Worker;
  var mainThread:Thread;

  var mutex = new Mutex();
  var lock = new Lock();

  var readWaiters = new ObjectMap<Socket, Array<Callback<Noise>>>();
  var writeWaiters = new ObjectMap<Socket, Array<Callback<Noise>>>();
  var registered = new ObjectMap<Socket, Bool>();

  var started = false;
  var shutdown = false;

  #if test
  var _waitReadableCount = 0;
  var _waitWritableCount = 0;
  var _selectCallCount = 0;
  #end

  public function new(?name, ?worker) {
    this.name = name == null ? 'SelectPool' : name;
    this.worker = worker == null ? Worker.get() : worker;
    this.mainThread = Thread.current();
  }

  public function register(socket:Socket):Void {
    var isNew = false;

    mutex.acquire();
    if (!registered.exists(socket)) {
      registered.set(socket, true);
      isNew = true;
    }
    mutex.release();

    if (isNew) {
      socket.setBlocking(false);
      ensureStarted();
    }
  }

  public function wait(socket:Socket, read:Bool):Future<Noise> {
    register(socket);

    return Future.async(function (cb) {
      mutex.acquire();
      var waiters = read ? readWaiters : writeWaiters;
      var list = waiters.get(socket);
      if (list == null) {
        list = [];
        waiters.set(socket, list);
      }
      list.push(cb);
      #if test
      if (read) _waitReadableCount++; else _waitWritableCount++;
      #end
      mutex.release();

      lock.release();
    });
  }

  public function close():Void {
    shutdown = true;
    lock.release();
  }

  #if test
  public function waitReadableCount():Int
    return _waitReadableCount;

  public function waitWritableCount():Int
    return _waitWritableCount;

  public function selectCallCount():Int
    return _selectCallCount;
  #end

  function ensureStarted():Void {
    if (started) return;

    mutex.acquire();
    var shouldStart = !started;
    if (shouldStart) started = true;
    mutex.release();

    if (shouldStart)
      Thread.create(loop);
  }

  function dispatch(cb:Callback<Noise>):Void {
    if (worker == Worker.EAGER)
      mainThread.events.run(function () cb.invoke(Noise));
    else
      worker.work(function () {
        cb.invoke(Noise);
        return Noise;
      });
  }

  function loop():Void {
    while (true) {
      mutex.acquire();
      if (shutdown) {
        var toWake = collectAll();
        mutex.release();
        for (cb in toWake) dispatch(cb);
        return;
      }

      var readArr = [for (s in readWaiters.keys()) s];
      var writeArr = [for (s in writeWaiters.keys()) s];
      var otherArr = [for (s in registered.keys()) s];
      mutex.release();

      if (readArr.length == 0 && writeArr.length == 0 && otherArr.length == 0) {
        lock.wait(0.2);
        continue;
      }

      #if test
      _selectCallCount++;
      #end

      var result =
        try Socket.select(readArr, writeArr, otherArr, 0.1)
        catch (e:Dynamic) { read: [], write: [], others: [] };

      var toNotify = [];

      mutex.acquire();
      collectReady(readWaiters, result.read.concat(result.others), toNotify);
      collectReady(writeWaiters, result.write.concat(result.others), toNotify);
      mutex.release();

      for (cb in toNotify) dispatch(cb);
    }
  }

  function collectReady(waiters:ObjectMap<Socket, Array<Callback<Noise>>>, ready:Array<Socket>, out:Array<Callback<Noise>>):Void {
    for (socket in ready) {
      var list = waiters.get(socket);
      if (list != null) {
        waiters.remove(socket);
        for (cb in list) out.push(cb);
      }
    }
  }

  function collectAll():Array<Callback<Noise>> {
    var out = [];
    for (list in readWaiters) for (cb in list) out.push(cb);
    for (list in writeWaiters) for (cb in list) out.push(cb);
    readWaiters = new ObjectMap();
    writeWaiters = new ObjectMap();
    return out;
  }
}

#end
