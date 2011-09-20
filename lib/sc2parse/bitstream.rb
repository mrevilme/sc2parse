module SC2Parse
  class BitStream
    attr_reader :offset

    def initialize(data, offset = 0)
      @data = data
      @offset = offset
    end

    def size
      @data.size
    end

    def each
      yield while @offset < @data.size
    end

    def peek
      @data[@offset]
    end

    def skip(num = 1)
      @offset += num
    end

    def read_byte
      read_bytes 1
    end

    def read_bytes(num)
      bytes = @data[@offset,num]
      skip num
      bytes
    end
    
    def read_bytes_to_array(num)
      bytes = []
      (0..num).each do |i|
        bytes << read_byte
      end
      bytes
    end

    def read_format(num, format)
      read_bytes(num).unpack format
    end

    def read_small_int
      read_format(1, 'C').first
    end

    def read_big_int
      read_format(4, 'L').first
    end

    def read_string(length)
      read_format(length, "A#{length}").first
    end

    def read_blizzard_vlf
      byte = read_small_int
      value, shift = (byte & 0x7F), 1
      until byte & 0x80 == 0
        byte = read_small_int
        value += (byte & 0x7F) << (7 * shift)
        shift += 1
      end
      convert_to_int value
    end
    
    def convert_to_int(blizz_int)
      (blizz_int & 1) == 1 ? -(blizz_int >> 1) : (blizz_int >> 1)
    end
  end
end
