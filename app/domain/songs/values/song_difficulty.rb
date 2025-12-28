# frozen_string_literal: true

require 'dry-types'
require 'dry-struct'

module LingoBeats
  module Value
    # Value object describing a song's difficulty analysis
    class SongDifficulty < Dry::Struct
      include Dry.Types

      attribute :distribution, Hash.map(String, Integer)
      attribute :level_code,   String.optional
      attribute :level_label,  String.optional
    end
  end
end
