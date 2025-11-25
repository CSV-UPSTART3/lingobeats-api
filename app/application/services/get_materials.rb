# frozen_string_literal: true

require 'dry/transaction'

module LingoBeats
  module Service
    class GetMaterials
      include Dry::Monads::Result::Mixin

      SONG_NOT_FOUND = 'Song not found'
      MATERIAL_NOT_FOUND = 'No vocabulary materials found'
      DB_ERROR = 'Having trouble accessing the database'

      def initialize(song_repo: Repository::For.klass(Entity::Song),
                     vocab_repo: Repository::For.klass(Entity::Vocabulary))
        @song_repo = song_repo
        @vocab_repo = vocab_repo
      end

      def call(input)
        song = @song_repo.find_id(input[:song_id])
        return Failure(Response::ApiResult.new(status: :not_found, message: SONG_NOT_FOUND)) unless song

        vocabs = @vocab_repo.for_song(song.id)
        return Failure(Response::ApiResult.new(status: :not_found, message: MATERIAL_NOT_FOUND)) if vocabs.empty?

        Success(
          Response::ApiResult.new(
            status: :ok,
            message: OpenStruct.new(
                song: song.name,
                materials: vocabs.map { |vocab| JSON.parse(vocab.material) }
              )
          )
        )
      rescue StandardError => error
        App.logger.error("[GetMaterials] #{DB_ERROR}: #{error.message}")
        Failure(Response::ApiResult.new(status: :internal_error, message: DB_ERROR))
      end
    end
  end
end
