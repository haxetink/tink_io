package tink.io;

private typedef Data = {
  ?end:Bool,
  ?destructive:Bool,
}

abstract PipeOptions(Data) from Data to Data { 
  
  public var end(get, never):Bool;
    inline function get_end()
      return this != null && this.end;
      
  public var destructive(get, never):Bool;
    inline function get_destructive()
      return this != null && this.destructive;
      
}