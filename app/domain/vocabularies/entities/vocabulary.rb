# frozen_string_literal: true

require 'json'
require 'dry-types'
require 'dry-struct'

module LingoBeats
  module Entity
    # Domain entity for song
    class Vocabulary < Dry::Struct
      include Dry.Types

      attribute :id,            Integer.optional
      attribute :name,          Strict::String
      attribute :original_word, Strict::String
      attribute :level,         Strict::String
      attribute :material,      Strict::String.optional # JSON string (nullable)

      # Helper: parse JSON → Hash
      def material_hash
        return nil if material.empty?

        ::JSON.generate(material)
      end

      # Helper: check if Gemini already enriched this vocab
      def material_blank?
        material.to_s.strip.empty?
      end

      def to_attr_hash
        to_h
      end
    end
  end
end
