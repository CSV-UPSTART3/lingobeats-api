# frozen_string_literal: true

require 'roar/decorator'
require 'roar/json'

require_relative 'openstruct_with_links'
require_relative 'vocabulary_representer'

module LingoBeats
  module Representer
    # Represents list of vocabulary materials
    class VocabulariesList < Roar::Decorator
      include Roar::JSON

      collection :vocabularies,
                 extend: Representer::Vocabulary,
                 class: Representer::OpenStructWithLinks
    end
  end
end
