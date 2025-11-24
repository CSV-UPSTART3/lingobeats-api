# frozen_string_literal: true

require 'dry/monads'

module LingoBeats
  module Service
    # Transaction to analyze song level with vocabulary data
    class AnalyzeSongLevel
      include Dry::Monads::Result::Mixin

      DB_ERROR = 'Having trouble accessing the database'
      SONG_LEVEL_ERROR = 'Failed to analyze song level'

      def initialize(song_repo: Repository::For.klass(Entity::Song), 
                     vocab_repo: Repository::For.klass(Entity::Vocabulary))
        super()
        @song_repo = song_repo
        @vocab_repo = vocab_repo
      end

      def call(input)
        song = @song_repo.find_id(input[:song_id])
        # average_level = average_difficulty(song)
        vocabs = @vocab_repo.for_song(song.id)
        distribution = vocabs.group_by(&:level).transform_values(&:count)
        filled = fill_levels(distribution)
        difficulty_label = weighted_average(filled, filled.values.sum)
        result_data = OpenStruct.new(
          distribution: filled,
          level: difficulty_label
        )
        Success(Response::ApiResult.new(status: :ok, message: result_data))
        
      rescue StandardError => error
        App.logger.error("[AnalyzeSongLevel] #{SONG_LEVEL_ERROR}: #{error.message}")
        Failure(Response::ApiResult.new(status: :internal_error, message: DB_ERROR))
      end

      private

      # fill empty levels, for example, if no B, it becomes { "A"=>x, "B"=>0, "C"=>y }
      def fill_levels(distribution)
        %w[A B C].each_with_object({}) do |level, hash|
          hash[level] = distribution.fetch(level, 0)
        end
      end

      # weighted average: (Σ score * count) / total_count
      def weighted_average(dist, total)
        return nil if total.zero?

        weighted_sum = dist.sum { |level, count| level_scores[level] * count }.to_f
        final_score = (weighted_sum / total).round(0)
        if final_score <= 1
          'Easy'
        elsif final_score == 2
          'Medium'
        else
          'Hard'
        end
      end

      # the mapping of level to score
      def level_scores
        {
          'A' => 1,
          'B' => 2,
          'C' => 3
        }.freeze
      end
    end
  end
end
