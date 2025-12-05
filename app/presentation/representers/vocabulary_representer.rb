# frozen_string_literal: true

require 'roar/decorator'
require 'roar/json'

module LingoBeats
  module Representer
    # Represents essential Vocabulary information for API output
    class Vocabulary < Roar::Decorator
      include Roar::JSON

      property :word,
               getter: ->(represented:, **) { represented[:word] || represented['word'] }

      property :level,
               getter: ->(represented:, **) { represented[:level] || represented['level'] }

      property :head_zh,
               getter: ->(represented:, **) { represented[:head_zh] || represented['head_zh'] }

      property :meanings,
               getter: ->(represented:, **) { represented[:meanings] || represented['meanings'] }

      property :related_forms,
               getter: ->(represented:, **) { represented[:related_forms] || represented['related_forms'] || [] }
    end
  end
end
