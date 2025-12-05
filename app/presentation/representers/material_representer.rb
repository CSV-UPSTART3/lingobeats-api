# frozen_string_literal: true

require 'roar/decorator'
require 'roar/json'

require_relative 'openstruct_with_links'
require_relative 'vocabulary_representer'

module LingoBeats
  module Representer
    # Represents essential Material information for API output
    class Material < Roar::Decorator
      include Roar::JSON

      property :song
      collection :contents,
                 extend: Representer::Vocabulary,
                 class: Representer::OpenStructWithLinks
    end
  end
end
