module SC2Parse
  class Replay
    module Header
      def self.parse (path)
        stream = BitStream.new IO.read(path)
        magic = stream.read_bytes(3)
        format = stream.read_small_int

        data_max_size = stream.read_big_int
        header_offset = stream.read_big_int
        user_data_header_size = stream.read_big_int
        data_type = stream.read_small_int
        num_elements = stream.read_blizzard_vlf

        index = stream.read_blizzard_vlf
        type = stream.read_small_int
        num_values = stream.read_blizzard_vlf
        starcraft2 = stream.read_string(num_values)

        index2 = stream.read_blizzard_vlf
        type2 = stream.read_small_int
        num_elements_version = stream.read_blizzard_vlf
        version = []
        while num_elements_version > 0
          i = stream.read_blizzard_vlf
          t = stream.read_small_int
          case t
          when 0x09
            version << stream.read_blizzard_vlf.to_s
          when 0x06
            version << stream.read_bytes(4).to_s
          when 0x07
            version << stream.read_big_int.to_s
          end
          num_elements_version -= 1
        end
        ["#{version[0]}.#{version[1]}.#{version[2]}.#{version[3]}", version[4]]
      end
    end
  end
end