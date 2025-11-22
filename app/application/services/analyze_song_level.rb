# frozen_string_literal: true

require 'dry/monads'

module LingoBeats
  module Service
    # Transaction to analyze song level with vocabulary data
    class AnalyzeSongLevel
      include Dry::Monads::Result::Mixin

      DB_ERROR = 'Having trouble accessing the database'
      SONG_LEVEL_ERROR = 'Failed to analyze song level'

      def initialize(song_repo: Repository::For.klass(Entity::Song))
        super()
        @song_repo = song_repo
      end

      def call(input)
        song = @song_repo.find_id(input[:song_id])
        average_level = average_difficulty(song)
        Success(Response::ApiResult.new(status: :ok, message: average_level))
      rescue StandardError => error
        App.logger.error("[AnalyzeSongLevel] #{SONG_LEVEL_ERROR}: #{error.message}")
        Failure(Response::ApiResult.new(status: :internal_error, message: DB_ERROR))
      end

      def average_difficulty(song)
        song.average_difficulty
      end
    end
  end
end
