# frozen_string_literal: true

require 'dry/monads'

module LingoBeats
  module Service
    # Transaction to store song when user selects a song
    class AddSong
      include Dry::Monads::Result::Mixin

      def initialize(repo: Repository::For.klass(Entity::Song))
        super()
        @repo = repo
      end

      def call(id)
        song = @repo.find_id(id) || @repo.ensure_song_exists(id)
        return Failure('Failed to store song to database') unless song

        Success(song)
      rescue StandardError => error
        Failure(error.to_s)
      end
    end
  end
end
