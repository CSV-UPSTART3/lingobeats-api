# frozen_string_literal: true

require 'dry/transaction'
require 'json'

module LingoBeats
  module Service
    # Transaction to analyze song level with vocabulary data
    class AnalyzeSongLevel
      include Dry::Transaction

      DB_ERROR = 'Having trouble accessing the database'          # → 500
      SONG_LEVEL_ERROR = 'Failed to analyze song level'           # → 500
      NO_LEVEL_INFO = 'No level information found for this song'  # → 404

      step :fetch_vocabs
      step :analyze_level
      step :build_result

      def initialize(
        songs_repo:  Repository::For.klass(Entity::Song),
        vocabs_repo: Repository::For.klass(Entity::Vocabulary)
      )
        super()
        @songs_repo  = songs_repo
        @vocabs_repo = vocabs_repo
      end

      private

      # step 1. fetch vocabularies for the song
      def fetch_vocabs(input)
        vocabs = @vocabs_repo.for_song(input[:song_id])
        return Failure(Response::ApiResult.new(status: :not_found, message: NO_LEVEL_INFO)) if vocabs.empty?

        Success(input.merge(vocabs: vocabs))
      rescue StandardError => error
        App.logger.error("[AnalyzeSongLevel] fetch_vocabs error: #{error.full_message}")
        Failure(Response::ApiResult.new(status: :internal_error, message: DB_ERROR))
      end

      # step 2. build distribution and difficulty label
      def analyze_level(input)
        calc_result = SongLevelCalculator.call(input[:vocabs])

        Success(input.merge(calc_result))
      rescue StandardError => error
        App.logger.error("[AnalyzeSongLevel] analyze_level error: #{error.full_message}")
        Failure(Response::ApiResult.new(status: :internal_error, message: SONG_LEVEL_ERROR))
      end

      # step 3. build API result object
      def build_result(input)
        result_data = Response::SongLevel.new(
          distribution: input[:distribution],
          level: input[:difficulty_label]
        )

        Success(Response::ApiResult.new(status: :ok, message: result_data))
      rescue StandardError => error
        App.logger.error("[AnalyzeSongLevel] build_result error: #{error.full_message}")
        Failure(Response::ApiResult.new(status: :internal_error, message: DB_ERROR))
      end

      # helper methods
      class SongLevelCalculator
        class << self
          def call(vocabs)
            distribution_raw = vocabs.group_by(&:level).transform_values(&:count)
            filled = fill_levels(distribution_raw)
            total = filled.values.sum
            difficulty_label = weighted_average(filled, total)

            {
              distribution: filled,
              difficulty_label: difficulty_label
            }
          end

          private

          # fill empty levels, for example, if no B, it becomes { "A"=>x, "B"=>0, "C"=>y }
          def fill_levels(distribution)
            %w[A B C].each_with_object({}) do |level, hash|
              hash[level] = distribution.fetch(level, 0)
            end
          end

          def weighted_average(dist, total)
            return nil if total.zero?

            score = (dist.sum { |level, count| level_scores[level] * count }.to_f / total).round

            case score
            when 0..1 then 'Easy'
            when 2    then 'Medium'
            else           'Hard'
            end
          end

          # level → score mapping
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
  end
end
