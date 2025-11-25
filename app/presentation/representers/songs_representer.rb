# frozen_string_literal: true

require 'roar/decorator'
require 'roar/json'

require_relative 'openstruct_with_links'
require_relative 'song_representer'

module LingoBeats
  module Representer
    # Represents list of songs for API output
    class SongsList < Roar::Decorator
      include Roar::JSON

      collection :songs, extend: Representer::Song,
                         class: Representer::OpenStructWithLinks
    end
  end
end
