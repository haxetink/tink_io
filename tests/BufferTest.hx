package ;

import haxe.io.Bytes;
import haxe.unit.TestCase;
import tink.io.Buffer;

class BufferTest extends TestCase {

	function testIndividual() {
		var buffer = Buffer.unmanaged(Bytes.alloc(0x100)),
				history = [],
				written = 0;
				
		function write(num:Int)
      buffer.readFrom({
        readBytes: function (into:Bytes, start, length) {
          if (num > length)
            num = length;
          for (i in 0...num) {
            var byte = Std.random(0x100);
            into.set(start + i, byte);
            history.push(byte);
          }
          written += num;
          return num;
        }
      });
			
		function read(num:Int)
      buffer.writeTo({
        writeBytes: function (bytes, start, len) {
          //assertTrue(len >= num);
          if (num > len)
            num = len;
          for (i in 0...num) {
            assertEquals(history.shift(), bytes.get(start + i));
          }
          return num;
        }
      });

			
		while (written < buffer.size << 3) {
			write(Std.random(buffer.freeBytes));
			read(Std.random(buffer.available));
		}
		read(buffer.available);
		read(buffer.available);
		assertEquals(0, buffer.available);
		
	}
	
	function testBulkWrite() 
		for (i in 0...100) {
			var buffer = Buffer.unmanaged(Bytes.alloc(0x10+i)),
					history = [],
					written = 0,
					bytesRead = 0;
					
      function write(num:Int)
        buffer.readFrom({
          readBytes: function (into:Bytes, start, length) {
            if (num > length)
              num = length;
            for (i in 0...num) {
              var byte = Std.random(0x100);
              into.set(start + i, byte);
              history.push(byte);
            }
            written += num;
            return num;
          }
        });
				
			function read(num:Int)
				buffer.writeTo( {
					writeBytes: function (bytes:Bytes, pos, length) {
						assertTrue(pos >= 0);
						assertTrue(pos + length <= bytes.length);
						if (length > num) length = num;
						num -= length;
						
						for (i in pos...pos+length) {
							assertEquals(history.shift(), bytes.get(i));
							written++;
						}
						return length;
					}
				});
				
			while (written < buffer.size << 3) {
				write(Std.random(buffer.freeBytes));			
				read(Std.random(buffer.available));
			}
			
			read(buffer.available);
			read(buffer.available);
			
			assertEquals(0, buffer.available);
		}
	
	function testBulkRead() 
		for (i in 0...100) {
			var buffer = Buffer.unmanaged(Bytes.alloc(0x10 + i)),
					history = [],
					written = 0,
					bytesRead = 0;
					
			function write(num:Int)
				buffer.readFrom( {
					readBytes: function (bytes:Bytes, pos, length) {
						assertTrue(pos >= 0);
						assertTrue(pos + length <= bytes.length);
						if (length > num) length = num;
						num -= length;
						for (i in pos...pos+length) {
							var byte = written % 203;
							bytes.set(i, byte);
							history.push(byte);
							written++;
						}
						return length;
					}
				});
				
		function read(num:Int)
      buffer.writeTo({
        writeBytes: function (bytes, start, len) {
          //assertTrue(len >= num);
          if (num > len)
            num = len;
          for (i in 0...num) {
            assertEquals(history.shift(), bytes.get(start + i));
          }
          bytesRead += num;
          return num;
        }
      });
				
			while (written < buffer.size << 3) {
				write(Std.random(buffer.freeBytes));			
				read(Std.random(buffer.available));
			}
			
			read(buffer.available);
			assertEquals(0, buffer.available);
			
		}	
}