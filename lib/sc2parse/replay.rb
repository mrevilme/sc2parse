require 'libmpq'

module SC2Parse
  class Replay
    autoload :Details, 'sc2parse/replay/details'
    autoload :InitData, 'sc2parse/replay/init_data'
    autoload :Attributes, 'sc2parse/replay/attributes'
    autoload :GameEvents, 'sc2parse/replay/game_events'
    autoload :Header, 'sc2parse/replay/header'
    attr_reader :version, :build
    
    def initialize(path)
      @archive = MPQ::Archive.new path
      (@version,@build) = Header.parse(path)
      parse_files
      aggregate
    end

    private
    def parse_files

      @archive.each_with_data do |file, data|
        case file
        when 'replay.details'
          @details = Details.parse data
        when 'replay.initData'
          @init_data = InitData.parse data
        when 'replay.attributes.events'
          @attributes = Attributes.parse data
        when 'replay.game.events'
          @game_events = GameEvents.parse(data, self)
        end
      end
    end

    def aggregate
    end
  end
end
