# frozen_string_literal: true

module LingoBeats
  module Validator
    # Validates vocabulary material input from Gemini API
    class VocabularyInput
      REQUIRED_ROOT_KEYS = %i[word head_zh meanings related_forms].freeze

      def self.call(raw_hash:, word:)
        validator = new(raw_hash || {}, word)
        result = validator.to_db_json

        App.logger.warn("Invalid material for word=#{word}, raw=#{raw_hash.inspect}") unless result

        result
      end

      def initialize(raw_hash, word)
        @raw = raw_hash || {}
        @word = word
      end

      # returns nil if invalid
      def to_db_json
        return unless valid?

        {
          'head_zh'       => @raw[:head_zh],
          'meanings'      => @raw[:meanings],
          'related_forms' => @raw[:related_forms] || []
        }
      end

      def valid?
        valid_root_structure? &&
          valid_word? &&
          valid_meanings? &&
          valid_related_forms?
      end

      private

      # ------- basic structure -------

      def valid_root_structure?
        return false unless @raw.is_a?(Hash)

        keys = @raw.keys.map(&:to_sym)
        missing = REQUIRED_ROOT_KEYS - keys
        missing.empty?
      end

      # ------- verification methods -------

      # --- word ---
      def valid_word?
        raw_word = @raw[:word]
        return false unless raw_word.is_a?(String)

        raw_word.strip.casecmp?(@word.to_s.strip)
      end

      # --- meanings ---
      # :reek:FeatureEnvy
      def valid_meanings?
        meanings = @raw[:meanings]
        return false unless meanings.is_a?(Array) && meanings.any?

        meanings.all? { |meaning| valid_meaning?(meaning) }
      end

      # :reek:FeatureEnvy
      def valid_meaning?(meaning)
        return false unless meaning.is_a?(Hash)

        pos           = meaning[:pos]
        definition_en = meaning[:definition_en]
        definition_zh = meaning[:definition_zh]
        examples      = meaning[:examples]

        pos.is_a?(String) &&
          definition_en.is_a?(String) &&
          definition_zh.is_a?(String) &&
          valid_examples?(examples)
      end

      # :reek:FeatureEnvy
      def valid_examples?(examples)
        return false unless examples.is_a?(Array) && examples.any?

        examples.all? { |example| valid_example?(example) }
      end

      # :reek:UtilityFunction
      def valid_example?(example)
        return false unless example.is_a?(Hash)

        sentence_en    = example[:sentence_en]
        explanation_zh = example[:explanation_zh]

        sentence_en.is_a?(String) && explanation_zh.is_a?(String)
      end

      # --- related_forms ---
      # :reek:FeatureEnvy
      def valid_related_forms?
        # allow empty
        related = @raw[:related_forms] || []
        return false unless related.is_a?(Array)

        related.all? { |relation| valid_relation?(relation) }
      end

      def valid_relation?(relation)
        return false unless relation.is_a?(Hash)

        form = relation[:form]
        pos  = relation[:pos]

        form.is_a?(String) && pos.is_a?(String)
      end
    end
  end
end
