# frozen_string_literal: true

require 'dry-types'
require 'dry-struct'

require_relative 'singer'
require_relative '../values/lyric'
require_relative '../values/song_difficulty'
require_relative '../services/song_difficulty_analyzer'

module LingoBeats
  module Entity
    # Domain entity for song
    class Song < Dry::Struct
      include Dry.Types

      attribute :id,              Strict::String
      attribute :name,            Strict::String
      attribute :uri,             Strict::String
      attribute :external_url,    Strict::String
      attribute :album_id,        Strict::String
      attribute :album_name,      Strict::String
      attribute :album_url,       Strict::String
      attribute :album_image_url, Strict::String
      attribute :lyric,           Value::Lyric.optional
      attribute :singers,         Strict::Array.of(Singer)

      def to_attr_hash
        to_h.except(:lyric, :singers)
      end

      def lyrics
        lyric&.text&.strip
      end

      # :reek:FeatureEnvy
      def eql?(other)
        return false unless other.is_a?(Song)

        comparison_key.eql?(other.comparison_key)
      end

      alias == eql?

      # Compare by name and first singer's id
      def comparison_key
        [name, singers.first&.id]
      end

      def hash
        comparison_key.hash
      end

      # Remove unqualified songs (e.g., instrumental, non-English)
      def self.remove_unqualified_songs(songs)
        songs.select(&:qualified?)
      end

      def qualified?
        !instrumental? && english_name?
      end

      # Check if the song is instrumental version
      def instrumental?
        name.match?(/instrument(al)?/i)
      end

      # Check if the song name is in English
      def english_name?
        name.ascii_only?
      end

      def evaluate_words
        return {} unless lyric

        lyric&.evaluate_difficulty # 呼叫 Lyric 的斷詞邏輯，並且進行評級
        # puts "[DEBUG] evaluate_words result size=#{result.size}, sample=#{result.class}"
        # puts "[DEBUG] evaluate_words first: #{result.first.inspect}"
      end

      def difficulty_distribution
        difficulty_analysis.distribution
      end

      def average_difficulty
        difficulty_analysis.level_code
      end

      # 要在 controller require service
      def generate_vocab_materials(vocabulary_service:)
        vocabulary_service.call(self)
      end

      private

      def difficulty_analysis
        @difficulty_analysis ||= difficulty_analyzer.from_levels(word_levels)
      end

      def difficulty_analyzer
        Songs::Services::SongDifficultyAnalyzer
      end

      def word_levels
        evaluate_words&.values || []
      end
    end
  end
end
