# frozen_string_literal: true

require 'roar/json'
require 'ostruct'

module LingoBeats
  module Representer
    # Represents a material generation job message
    class MaterialJob < Roar::Decorator
      include Roar::JSON

      property :song_id
      property :request_id

      def self.serialize(song_id:, request_id:)
        payload = OpenStruct.new(song_id:, request_id:)
        new(payload).to_json
      end

      def self.from_json(json)
        new(OpenStruct.new).from_json(json)
      end
    end
  end
end
