# frozen_string_literal: true

require 'dry-types'
require 'dry-struct'

require_relative 'singer'
require_relative '../values/lyric'

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

      # Remove duplicates by name + first singer id
      def ==(other)
        other.respond_to?(:comparison_key) && comparison_key == other.comparison_key
      end
      alias eql? ==

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
        # 允許英文、數字、空白、常見符號、以及少數變音字母
        # name.match?(/\A[0-9A-Za-z\s'&.,!?\-éáíóúñÉÁÍÓÚ]+(?:\s*\(.*\))?\z/)
      end

      def evaluate_words
        return [] unless lyric

        lyric&.evaluate_difficulty || {} # 呼叫 Lyric 的斷詞邏輯，並且進行評級
      end

      def difficulty_distribution
        fill_levels(base_distribution)
      end

      def average_difficulty
        dist = difficulty_distribution
        return if dist.empty?

        total = dist.values.sum
        return if total.zero?

        LEVEL_SCORES.key(weighted_average(dist, total).round)
      end

      private

      def base_distribution
        evaluate_words.each_value.with_object(Hash.new(0)) do |level, hash|
          hash[level] += 1 if level
        end
      end

      # Helpers for calculating song difficulty
      module SongDifficultyHelper
        module_function

        def weighted_average(dist, total)
          weighted = dist.sum { |level, count| LEVEL_SCORES[level] * count }.to_f
          weighted / total
        end

        def fill_levels(distribution)
          %w[A1 A2 B1 B2 C1 C2].each_with_object({}) do |level, hash|
            hash[level] = distribution.fetch(level, 0)
          end
        end

        def level_scores
          {
            'A1' => 1, 'A2' => 2,
            'B1' => 3, 'B2' => 4,
            'C1' => 5, 'C2' => 6
          }.freeze
        end

        def weighted_average_score(dist, total)
          weighted = dist.sum { |level, count| level_scores[level] * count }.to_f
          weighted / total
        end
      end
    end
  end
end
