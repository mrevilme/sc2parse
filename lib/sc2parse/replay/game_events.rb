require 'ruby-debug'
require 'pp'

module SC2Parse
  class Replay
    module GameEvents
      def self.parse(data, replay)
        @@replay = replay
        @@stream = BitStream.new data
        player_left = []
        events = []
        previous_event_byte = 0
        time = 0
        num_events = 0
        num_byte = 0
        event_type = 0
        event_code = 0 
        @@stream.each do |va|
          known_event = true
          time_stamp = self.parse_time_stamp(@@stream)
          next_byte = @@stream.read_small_int
          if next_byte
            event_type = next_byte >> 5
            global_event_flag = next_byte & 16
            player_id = next_byte & 15

            event_code = @@stream.read_small_int 
            time += time_stamp
            num_events += 1

            if global_event_flag > 0 && player_id > 0
              known_event = false
            else
              case event_type
              when 0x01
                case event_code
                when 0x1B,0x2B,0x3B,0x4B,0x5B,0x6B,0x7B,0x8B,0x9B,0x0B # player uses an ability
                  self.parse_ability
                when 0x0C, 0x1C, 0x2C, 0x3C, 0x4C, 0x5C, 0x6C, 0x7C, 0x8C, 0x9C, 0xAC # player changes selection
                  self.parse_selection
                  puts "New event" if (event_code == 0xAC)
                when 0x0D,0x1D,0x2D,0x3D,0x4D,0x5D,0x6D,0x7D,0x8D,0x9D
                  self.parse_hotkey
                when 0x2F,0x3F,0x4F,0x5F,0x6F,0x7F,0x8F
                  self.parse_resource_send
                else
                  known_event = false
                  break
                end
              when 0x02
                case event_code
                when 0x06
                  @@stream.read_bytes 6
                when 0x07
                  @@stream.read_bytes 4
                when 0x49
                  
                else
                  known_event = false
                end
              when 0x03
                case event_code
                when 0x87
                  @stream.read_bytes 8
                when 0x08
                  @stream.read_bytes 10
                when 0x18
                  @stream.read_bytes 162
                when 0x01,0x11,0x21,0x31,0x41,0x51,0x61,0x71,0x81,0x91,0xA1,0xB1,0xC1,0xD1,0xE1,0xF1
                  self.parse_camera_movement
                else
                  known_event = false
                end
              when 0x04
                @@stream.read_bytes 2 if (event_code & 0x0F) == 2
                if (event_code & 0x0C) == 2
                  break
                end
                
                if (event_code & 0x0F) == 12
                  break
                end
                
                case event_code
                when 0x16
                  @@stream.read_bytes 24
                when 0xC6
                  @@stream.read_bytes 16
                when 0x18
                  @@stream.read_bytes 4
                when 0x87
                  @@stream.read_bytes 4
                else
                  known_event = false
                  break
                end
              when 0x05
                case event_code
                when 0x89
                  @@stream.read_bytes 4
                  break
                else
                  known_event = false
                  break
                end
              end
            end

          end

          if !known_event
            puts "Unkown event: Timestamp: #{time_stamp}, Type: #{event_type}, global: #{global_event_flag}, player: #{player_id}, event code: #{"%02X" % event_code} byte: #{"%08X" % event_code}"
          end
          # $eventCode = MPQFile::readByte($string,$numByte);
          # $time += $timeStamp;
          # $numEvents++;
        end
      end

      def self.parse_time_stamp(stream)
        # debugger
        one = stream.read_small_int
        if (one & 3) > 0 
          two = stream.read_small_int
          if two 
            two = ((one >> 2) << 8) | two
            if (one & 3) >= 2
              tmp = stream.read_small_int
              two = (two << 8) | tmp
              if (one & 3) == 3
                tmp = stream.read_small_int
                two = (two << 8) | tmp
              end
            end
          end
          return two
        end
        return one >> 2
      end

      private
      
      def self.parse_camera_movement
        @@stream.read_bytes 3
        nByte = @@stream.read_small_int
        aByte = nByte & 0x70
        case aByte
        when 0x10, 0x20, 0x30, 0x40, 0x50
          if aByte == 0x10 or aByte == 0x30 or aByte == 0x50
            @@stream.read_byte
            nByte = @@stream.read_small_int
          end
          
          if aByte != 0x40
            if (aByte & 0x20) > 0
              @@stream.read_byte
              nByte = @@stream.read_small_int
            end
            
            return if (nByte & 0x40) == 0
          end
          
          @@stream.read_bytes 2
        end
        
      end
      
      def self.parse_resource_send
        @@stream.read_byte
        # sender = playerId
        # receiver = (eventCode & 0xF=) >> 4
        
        #mineral sending
        bytes = @@stream.read_bytes_to_array 4
        mineral_value = (((bytes[0] << 20) | (bytes[1] << 12) | bytes[2] << 4 ) >> 1) + (bytes[3] & 0x0F)
        
        # gas sending
        bytes = @@stream.read_bytes_to_array 4
        gas_value = (((bytes[0] << 20) | (bytes[1] << 12) | bytes[2] << 4 ) >> 1) + (bytes[3] & 0x0F);
        
        @@stream.read_bytes 8
        
      end
      
      def self.parse_hotkey
        byte1 = @@stream.read_small_int
        flag = byte1 & 0x03
        # action = flag
        
        # eventtype = GameEventType.Selection if flag == 2
        
        byte2 = 0
        if (byte1 < 16) && ((byte1 & 0x8) == 8)
          b2 = (@@stream.read_small_int & 0xF)
          @@stream.read_bytes b2
        elsif byte1 > 4
          if byte1 < 8
            j = @@stream.read_small_int
            @@stream.read_small_int if (j & 0x7) > 4
            @@stream.read_small_int if (j & 0x8) != 0
          else
            j = @@stream.read_small_int
            shift = (byte >> 3) + ((j & 0xF) > 4 ? 1 : 0) + ((j & 0xF) > 12 ? 1 : 0)
            @@stream.read_bytes shift
            
            if @@replay.build.to_i >= 18574
              @@stream.read_bytes 14 if byte1 == 30 and j == 1
            end
            
          end
        end
      end
      
      def self.parse_selection
        if @@replay.build.to_i >= 16561 
          bitmask = 0
          nByte = 0
          @@stream.read_byte 
          deselectFlags = @@stream.read_small_int
          if (deselectFlags & 3) == 1
            deselectionBytes = (deselectFlags & 0xFC) | (nByte & 3)
            while deselectionBytes > 6
              nByte = @@stream.read_small_int
              deselectionBytes -= 8
            end
            
            deselectionBytes += 2
            deselectionBytes = deselectionBytes % 8
            
            bitmask = (2 ** deselectionBytes) - 1
          elsif ((deselectFlags & 3) == 2 || (deselectFlags & 3) == 3)
            nByte = @@stream.read_small_int
            deselectionBytes = (deselectFlags & 0xFC) | (nByte & 3)
            while deselectionBytes > 30
              nByte = @@stream.read_small_int
              deselectionBytes -= 1
            end
            bitmask = 3
          elsif ((deselectFlags & 3) == 0)
            bitmask = 3
            nByte = deselectFlags
          end
          
          num_unit_type_ids = 0
          prev_byte = nByte
          nByte = @@stream.read_small_int
          
          if bitmask > 0
            num_unit_type_ids = (prev_byte & (0xFF - bitmask)) | (nByte & bitmask)
          else
            num_unit_type_ids = nByte
          end
          
          (0..num_unit_type_ids).each do |i|
            unit_type_id = 0
            unit_type_count = 0
            (0..3).each do |j|
              by = 0
              prev_byte = nByte
              nByte = @@stream.read_small_int
              
              if bitmask > 3
                by = ((prev_byte & (0xFF - bitmask)) | (nByte && bitmask))
              else
                by = nByte
              end
              
              unit_type_id = by << ((2 - j) * 8) | unit_type_id
            end
            
            prev_byte = nByte
            nByte = @@stream.read_small_int
            
            if (bitmask > 0)
              unit_type_count = (prev_byte & (0xFF - bitmask)) | (nByte & bitmask)
            else
              unit_type_count = nByte
            end
            
          end
          
          num_units = 0
          prev_byte = nByte
          nByte = @@stream.read_small_int
          if bitmask > 0
            num_units = (prev_byte & (0xFF - bitmask)) | (nByte & bitmask)
          else
            num_units = nByte
          end
          
          (0..num_units).each do |i|
            unit_id = 0
            by = 0
            (0..4).each do |j|
              prev_byte = nByte
              nByte = @@stream.read_small_int
              if (bitmask > 0)
                by = (prev_byte & (0xFF - bitmask)) | (nByte & bitmask)
              else
                by = nByte
              end
              
              
              unit_id = (by << ((1 - j) * 8)) | unit_id if j < 2
              
            end
          end
          
          
        end
      end
      
      # nByte = reader.ReadByte();
      # var deselectionBits = (deselectFlags & 0xFC) | (nByte & 3);
      # while (deselectionBits > 6) {
      #     nByte = reader.ReadByte();
      #     deselectionBits -= 8;
      # }
      # deselectionBits += 2;
      # deselectionBits = deselectionBits % 8;
      # bitmask = (int)Math.Pow(2, deselectionBits) - 1;
      
      
      def self.parse_ability
        ability = -1
        first_byte = @@stream.read_small_int
        temp = @@stream.read_small_int
        if @@replay.build.to_i > 18317

          lastTemp = 0
          ability = @@stream.read_small_int << 16 | @@stream.read_small_int << 8 | (lastTemp = @@stream.read_small_int)

          if (first_byte & 0x0c) == 0x0c && (first_byte & 1) == 0
            @@stream.read_bytes 4
          elsif (temp == 64 || temp == 66)
            if lastTemp > 14
              if (lastTemp & 0x40) != 0
                @@stream.read_bytes 2
                @@stream.read_bytes 4
                @@stream.read_bytes 2
              else
                @@stream.read_bytes 6
              end
            end
          elsif (temp == 8 || temp == 10)
            @@stream.read_bytes 7
          elsif (temp == 136 || temp == 138)
            @@stream.read_bytes 15
          end

          if (ability != -1)
            puts "something happend"
          end
        end

        if ability == -1 
          ability = (@@stream.read_small_int << 16) | (@stream.read_small_int << 8) | (@@stream.read_small_int & 0x3)

          if temp == 0x20 || temp == 0x22
            nByte = ability & 0xFF
            if nByte > 0x07
              if first_byte == 0x29 || first_byte == 0x19
                @@stream.read_bytes 4
                return
              end

              @@stream.read_bytes 9

              if (nByte & 0x20) > 0
                @@stream.read_bytes 9
              end
            elsif (temp == 0x48 || temp == 0x4A)
              @@stream.read_bytes 7
            elsif (temp == 0x88 || temp == 0x8A)
              @@stream.read_bytes 15
            elsif (temp & 0x20) != 0
              # ehm
            end

            # ehm
          end

        end
      end
    end 
  end
end