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

      SONG_NOT_EXISTS = 'Cannot find the specified song'   # → 404
      MATERIAL_NOT_EXISTS = 'Material not generated yet'   # → 404
      DB_ERROR = 'Having trouble accessing the database'   # → 500
      MATERIAL_IN_QUEUE = 'Material is now generating'     # → 202

      def initialize(
        songs_repo: Repository::For.klass(Entity::Song),
        vocabs_repo: Repository::For.klass(Entity::Vocabulary)
      )
        super()
        @songs_repo = songs_repo
        @vocabs_repo = vocabs_repo
      end

      private

      # step 1. fetch song + validate materials exist
      def fetch_data(input)
        song     = find_song(input[:song_id])
        contents = @vocabs_repo.vocabs_content(song.id)
        status   = contents.empty? ? material_status(song.id) : :ok

        Success(input.merge(song_name: song.name, status:, contents:))
      rescue StandardError => error
        App.logger.error("[GetMaterial] fetch data error: #{error.full_message}")
        Failure(Response::ApiResult.new(status: :not_found, message: error.message || DB_ERROR))
      end

      # step 2. build API result
      def build_result(input)
        Success(Response::ApiResult.new(status: input[:status], message: result_message(input)))
      rescue StandardError => error
        App.logger.error("[GetMaterial] build result error: #{error.full_message}")
        Failure(Response::ApiResult.new(status: :internal_error, message: DB_ERROR))
      end

      # helper methods
      def find_song(song_id)
        song = @songs_repo.find_by_id(song_id)
        raise SONG_NOT_EXISTS unless song

        song
      end

      def material_status(song_id)
        Material::ProcessingLock.processing?(song_id) ? :processing : :not_found
      end

      def result_message(input)
        case input[:status]
        when :ok
          build_material_entity(input)
        when :processing
          MATERIAL_IN_QUEUE
        when :not_found
          MATERIAL_NOT_EXISTS
        end
      end

      # :reek:FeatureEnvy
      def build_material_entity(input)
        Response::Material.new(song: input[:song_name], contents: input[:contents])
      end
    end
  end
end
