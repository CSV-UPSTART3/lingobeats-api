# frozen_string_literal: true

require 'roar/decorator'
require 'roar/json'

module LingoBeats
  module Representer
    # Represents essential Material information for API output
    class Material < Roar::Decorator
      include Roar::JSON

      property :text
    end
  end
end
