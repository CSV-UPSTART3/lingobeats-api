# frozen_string_literal: true

require 'roar/json'

module LingoBeats
  module Representer
    # Represents a material generation job message
    class MaterialJob
      include Roar::JSON

      def initialize(song_id:, request_id:)
        @song_id = song_id
        @request_id = request_id
      end

      def to_json(*_args)
        {
          song_id: @song_id,
          request_id: @request_id
        }.to_json
      end

      def self.from_json(json)
        ::JSON.parse(json)
      end
    end
  end
end
