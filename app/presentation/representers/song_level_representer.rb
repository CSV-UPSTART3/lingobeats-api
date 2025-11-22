# frozen_string_literal: true

require 'roar/decorator'
require 'roar/json'

module LingoBeats
  module Representer
    # Represents essential Song Level information for API output
    class SongLevel < Roar::Decorator
      include Roar::JSON

      property :tag
    end
  end
end
