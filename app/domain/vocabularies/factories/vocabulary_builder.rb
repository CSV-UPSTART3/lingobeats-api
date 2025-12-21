# frozen_string_literal: true

require 'json'

module LingoBeats
  module Vocabularies
    # Helper class to build Vocabulary entities from difficulty data
    class VocabularyBuilder
      # difficulties: { "ghost" => "B1", "stage" => "A2", ... }
      # existing_names: ["ghost", ...]
      def self.build_from_difficulties(difficulties, existing_names:)
        # difficulties: [[original_word, lemma, level], ...]
        # candidates = difficulties.reject do |original_word, lemma, level|
        #   existing_names.include?(lemma) || !level
        # end
        candidates = difficulties.reject do |item|
          lemma = item["lemma"]
          level = item["level"]
          existing_names.include?(lemma) || !level
        end

        # puts "[DEBUG] candidates sample: #{candidates.first.inspect}"

        create_entities(candidates)
      end

      class << self
        private

        def create_entities(candidates)
          # candidates.map do |original_word, lemma, level|
          #   Entity::Vocabulary.new(
          #     id: nil,
          #     name: lemma,
          #     original_word: original_word,
          #     level: level,
          #     material: nil
          #   )
          # end
          candidates.map do |item|
            lemma = item["lemma"]
            original_word = item["origin_word"]
            level = item["level"]

            # puts "[DEBUG] Creating entity for lemma=#{lemma}, original_word=#{original_word}, level=#{level}"

            Entity::Vocabulary.new(
              id: nil,
              name: lemma,
              original_word: original_word,
              level: level,
              material: nil
            )
          end
        end
      end
    end
  end
end
