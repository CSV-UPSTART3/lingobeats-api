# frozen_string_literal: true

require 'roar/decorator'
require 'roar/json'

module LingoBeats
  module Representer
    # Represents essential Lyric information for API output
    # USAGE:
    #  lyric = Database::LyricOrm.first
    #  Representer::Lyric.new(lyric).to_json
    class Lyric < Roar::Decorator
      include Roar::JSON

      property :text
    end
  end
end
