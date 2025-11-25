# frozen_string_literal: true

require 'dry/transaction'
require 'json'

module LingoBeats
  module Service
    # Transaction to get existed & complete learning materials for vocabularies of a song
    class GetMaterial
      include Dry::Transaction

      step :fetch_data
      step :build_result

      SONG_NOT_EXISTS = 'Cannot find the specified song'  # → 404
      MATERIAL_NOT_EXISTS = 'No learning materials found' # → 404
      DB_ERROR = 'Having trouble accessing the database'  # → 500

      def initialize(
        songs_repo: Repository::For.klass(Entity::Song),
        vocabs_repo: Repository::For.klass(Entity::Vocabulary)
      )
        super()
        @songs_repo = songs_repo
        @vocabs_repo = vocabs_repo
      end

      # step 1. fetch song + validate materials exist
      def fetch_data(input)
        song = find_valid_song(input[:song_id])

        Success(input.merge(song_name: song.name))
      rescue StandardError => error
        App.logger.error("[GetMaterial] fetch data error: #{error.full_message}")
        Failure(Response::ApiResult.new(status: :not_found, message: error.message || DB_ERROR))
      end

      # step 2. build API result
      def build_result(input)
        result = Response::Material.new(song: input[:song_name], contents: @vocabs_repo.vocabs_content(input[:song_id]))

        Success(Response::ApiResult.new(status: :ok, message: result))
      rescue StandardError => error
        App.logger.error("[GetMaterial] build result error: #{error.full_message}")
        Failure(Response::ApiResult.new(status: :internal_error, message: DB_ERROR))
      end

      # helper methods
      def find_valid_song(song_id)
        song = @songs_repo.find_by_id(song_id)
        raise SONG_NOT_EXISTS unless song
        raise MATERIAL_NOT_EXISTS if @vocabs_repo.incomplete_material?(song_id)

        song
      end
    end
  end
end
