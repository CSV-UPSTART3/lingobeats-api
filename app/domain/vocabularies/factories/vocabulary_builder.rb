# frozen_string_literal: true

require 'json'

module LingoBeats
  module Vocabularies
    # Helper class to build Vocabulary entities from difficulty data
    class VocabularyBuilder
      # difficulties: { "ghost" => "B1", "stage" => "A2", ... }
      # existing_names: ["ghost", ...]
      def self.build_from_difficulties(difficulties, existing_names:)
        candidates = difficulties.reject do |word, level|
          existing_names.include?(word) || !level
        end

        create_entities(candidates)
      end

      class << self
        private

        def create_entities(candidates)
          candidates.map do |word, level|
            Entity::Vocabulary.new(
              id: nil,
              name: word,
              level: level,
              material: nil
            )
          end
        end
      end
    end
  end
end
