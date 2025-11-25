# frozen_string_literal: true

require 'dry/monads'

module LingoBeats
  module Service
    # Transaction to store song when user selects a song
    class AddSong
      include Dry::Monads::Result::Mixin

      DB_ERROR = 'Having trouble accessing the database'

      def initialize(repo: Repository::For.klass(Entity::Song))
        super()
        @repo = repo
      end

      def call(input)
        status, song = SongFinder.new(@repo).call(input[:song_id])

        Success(Response::ApiResult.new(status:, message: song))
      rescue StandardError
        Failure(Response::ApiResult.new(status: :internal_error, message: DB_ERROR))
      end

      # helper methods
      class SongFinder
        DB_FIND_SONG_ERROR = 'Database error when finding song'
        DB_STORE_SONG_ERROR = 'Database error when creating song'

        def initialize(repo)
          @repo = repo
        end

        def call(id)
          song = find_song(id)
          return [:ok, song] if song

          created = create_song(id)
          [:created, created]
        end

        def find_song(id)
          @repo.find_id(id)
        rescue StandardError
          App.logger.error("[SongFinder] #{DB_FIND_SONG_ERROR}")
          raise
        end

        private

        def create_song(id)
          @repo.ensure_song_exists(id)
        rescue StandardError
          App.logger.error("[SongFinder] #{DB_STORE_SONG_ERROR}")
          raise
        end
      end
    end
  end
end
