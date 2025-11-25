# frozen_string_literal: true

require 'roar/decorator'
require 'roar/json'

module LingoBeats
  module Representer
    # Represents essential Singer information for API output
    class Singer < Roar::Decorator
      include Roar::JSON

      property :id
      property :name
      property :external_url
    end
  end
end
