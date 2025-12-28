# frozen_string_literal: true

module LingoBeats
  module Validator
    # Validates vocabulary material input from Gemini API
    class VocabularyInput
      REQUIRED_ROOT_KEYS = %i[word head_zh meanings related_forms].freeze

      def self.call(raw_hash:, word:)
        validator = new(MaterialPayload.new(raw_hash), word)
        result = validator.to_db_json

        App.logger.warn("Invalid material for word=#{word}, raw=#{raw_hash.inspect}") unless result

        result
      end

      def initialize(payload, word)
        @payload = payload
        @word = word
      end

      # returns nil if invalid
      def to_db_json
        return unless valid?

        {
          'head_zh'       => @payload[:head_zh],
          'meanings'      => @payload[:meanings],
          'related_forms' => @payload[:related_forms] || []
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
        return false unless @payload.hash?

        keys = @payload.keys.map(&:to_sym)
        missing = REQUIRED_ROOT_KEYS - keys
        missing.empty?
      end

      # ------- verification methods -------

      # --- word ---
      def valid_word?
        raw_word = @payload[:word]
        return false unless raw_word.is_a?(String)

        raw_word.strip.casecmp?(@word.to_s.strip)
      end

      # --- meanings ---
      # :reek:FeatureEnvy
      def valid_meanings?
        meanings = @payload[:meanings]
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
        related = @payload[:related_forms] || []
        return false unless related.is_a?(Array)

        related.all? { |relation| RelatedForm.new(relation).valid? }
      end

      # Wraps raw material input to provide consistent access
      class MaterialPayload
        def initialize(raw_hash)
          @raw = raw_hash
        end

        def hash?
          @raw.is_a?(Hash)
        end

        def keys
          hash? ? @raw.keys : []
        end

        def [](key)
          return nil unless hash?

          @raw[key]
        end
      end

      # Validates a related form entry
      class RelatedForm
        def initialize(raw_relation)
          @raw = raw_relation
        end

        def valid?
          return false unless @raw.is_a?(Hash)

          form.is_a?(String) && pos.is_a?(String)
        end

        private

        def form = @raw[:form]
        def pos = @raw[:pos]
      end
    end
  end
end
