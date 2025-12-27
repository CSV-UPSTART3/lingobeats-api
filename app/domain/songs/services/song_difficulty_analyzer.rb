# frozen_string_literal: true

require_relative '../values/song_difficulty'

module LingoBeats
  module Songs
    module Services
      # Domain service that analyzes difficulty based on vocabulary levels
      class SongDifficultyAnalyzer
        LEVEL_CODES = %w[A B C].freeze
        LEVEL_SCORES = {
          'A' => 1,
          'B' => 2,
          'C' => 3
        }.freeze
        LEVEL_LABELS = {
          1 => 'Easy',
          2 => 'Medium',
          3 => 'Hard'
        }.freeze

        class << self
          def from_vocabs(vocabs)
            levels = vocabs.filter_map(&:level)
            analyze(levels)
          end

          def from_levels(levels)
            analyze(levels.compact)
          end

          private

          def analyze(levels)
            distribution = distribution_from(levels)
            score = average_score(distribution)
            Value::SongDifficulty.new(
              distribution: distribution,
              level_code: level_code_for(score),
              level_label: level_label_for(score)
            )
          end

          def average_score(distribution)
            total = distribution.values.sum
            return nil if total.zero?

            weighted = distribution.sum { |level, count| LEVEL_SCORES[level] * count }.to_f
            (weighted / total).round
          end

          def level_code_for(score)
            return nil unless score

            LEVEL_SCORES.key(score)
          end

          def level_label_for(score)
            return nil unless score

            LEVEL_LABELS.fetch(score, LEVEL_LABELS[3])
          end

          def distribution_from(levels)
            distribution = LEVEL_CODES.each_with_object({}) do |level, hash|
              hash[level] = 0
            end
            levels.each do |level|
              next unless LEVEL_SCORES.key?(level)

              distribution[level] += 1
            end
            distribution
          end
        end
      end
    end
  end
end
