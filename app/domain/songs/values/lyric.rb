# frozen_string_literal: true

require 'dry-types'
require 'dry-struct'
require 'digest'
require 'cld3'

# require 'pycall/import'

module LingoBeats
  module Value
    # Value object for song
    class Lyric < Dry::Struct
      # include PyCall::Import
      # pyimport :langdetect
      include Dry.Types

      LEVEL_CODE_MAP = {
        'A' => 'A',
        'B' => 'B',
        'C' => 'C'
      }.freeze

      attribute :text, Strict::String.optional

      # get id by checksum of normalized text
      def checksum
        Digest::SHA256.hexdigest(normalized_text)
      end

      def normalized_text
        (text || '').strip.gsub(/\s+/, ' ')
      end

      # Detect if lyric is English using CLD3
      def english?
        return false if text.to_s.strip.empty?

        detector = CLD3::NNetLanguageIdentifier.new(0, 512)
        result = detector.find_language(text)

        # 若偵測失敗或結果為 nil
        return false unless result

        # 回傳是否為英文（機率閾值 0.9）
        result.language == :en && result.probability > 0.9
      end

      def clean_words
        return [] if text.to_s.strip.empty?

        cleaned_text = lyric_cleaner.new(text).call
        lyric_tokenizer.new(cleaned_text).call # array of words
      end

      def evaluate_difficulty
        words = clean_words
        results = difficulty_estimator.new(words).call

        # puts "[DEBUG] evaluate_difficulty results sample: #{results.first.inspect}"

        # let A1/A2 → A, B1/B2 → B, C1/C2 → C
        results.map { |result| collapse_level(result) }
               .compact
        # puts "[DEBUG] Mapped results sample: #{mapped_results.first.inspect}"
      end

      def collapse_level(result)
        collapsed = self.class.collapse_level_code(result['level'])
        return nil unless collapsed

        { **result, 'level' => collapsed }
      end

      def self.collapse_level_code(raw_level)
        LEVEL_CODE_MAP[raw_level.to_s[0]]
      end

      private

      def lyric_cleaner
        Songs::Services::Cleaner
      end

      def lyric_tokenizer
        Songs::Services::Tokenizer
      end

      def difficulty_estimator
        Songs::Services::DifficultyEstimator
      end
    end
  end
end
