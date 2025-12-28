# frozen_string_literal: true

require 'dry/transaction'
require 'json'

require_relative '../../domain/songs/services/song_difficulty_analyzer'

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
        analysis = Songs::Services::SongDifficultyAnalyzer.from_vocabs(input[:vocabs])
        Success(
          input.merge(
            distribution: analysis.distribution,
            difficulty_label: analysis.level_label
          )
        )
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
    end
  end
end
