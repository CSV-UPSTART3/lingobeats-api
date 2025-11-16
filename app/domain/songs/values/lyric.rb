# frozen_string_literal: true

require 'dry-types'
require 'dry-struct'
require 'digest'
require 'cld3'

require_relative 'cleaner'
require_relative 'tokenizer'
# require 'pycall/import'

module LingoBeats
  module Value
    # Value object for song
    class Lyric < Dry::Struct
      # include PyCall::Import
      # pyimport :langdetect
      include Dry.Types

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

        cleaned_text = Cleaner.new(text).call
        Tokenizer.new(cleaned_text).call # array of words
      end

      def evaluate_difficulty
        words = clean_words
        results = DifficultyEstimator.new(words).call

        results.reject { |_word, lvl| [nil, 'None'].include?(lvl) }
      end
    end
  end
end
