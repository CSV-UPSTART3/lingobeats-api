# frozen_string_literal: true

require 'dry/transaction'
require 'ostruct'
require 'json'

module LingoBeats
  module Service
    # Transaction to add learning materials for vocabularies of a song
    class AddMaterial
      include Dry::Transaction

      step :fetch_data
      step :find_pending
      step :queue_pending_materials
      step :build_result

      def initialize(
        songs_repo: Repository::For.klass(Entity::Song),
        vocabs_repo: Repository::For.klass(Entity::Vocabulary),
        mapper: LingoBeats::Gemini::VocabularyMapper.new(
          access_token: App.config.GEMINI_API_KEY
        )
      )
        super()
        @songs_repo = songs_repo
        @vocabs_repo = vocabs_repo
        @mapper = mapper
      end

      SONG_NOT_EXISTS = 'Cannot find the specified song'                # → 404
      VOCAB_NOT_EXISTS = 'Cannot find the vocabularies in the song'     # → 404
      DB_ERROR = 'Having trouble accessing the database'                # → 500
      MATERIAL_GENERATE_ERROR = 'Failed to generate learning materials' # → 500
      MATERIAL_GENERATE_QUEUED = 'Material generation job queued'       # → 202

      private

      # step 1. fetch song + vocabs
      def fetch_data(input)
        song = find_song(input[:song_id])
        Success({ song:, vocabs: find_vocabs(song.id) })
      rescue StandardError => error
        App.logger.error("[AddMaterial] fetch data error: #{error.full_message}")
        Failure(Response::ApiResult.new(status: :internal_error, message: error.message || DB_ERROR))
      end

      # step 2. find which vocabs need material
      def find_pending(input)
        pending_vocabs = input[:vocabs].select(&:material_blank?)

        Success(input.merge(pending_vocabs:))
      rescue StandardError => error
        App.logger.error("[AddMaterial] find pending error: #{error.full_message}")
        Failure(Response::ApiResult.new(status: :internal_error, message: DB_ERROR))
      end

      # step 3. only generate materials for pending vocabs
      def queue_pending_materials(input)
        pending_vocabs = input[:pending_vocabs]
        return Success({ song: input[:song] }) if pending_vocabs.empty?

        message = LingoBeats::Representer::MaterialJob
              .new(song_id: input[:song].id)
              .to_json

        Messaging::Queue.new(App.config.MATERIAL_QUEUE_URL, App.config)
          .send(message)

        Success(input.merge(status: :processing))

      rescue StandardError => error
        App.logger.error("[AddMaterial] generate materials error: #{error.full_message}")
        Failure(Response::ApiResult.new(status: :internal_error, message: MATERIAL_GENERATE_ERROR))
      end

      def build_result(input)
        Success(Response::ApiResult.new(status: input[:status], message: MATERIAL_GENERATE_QUEUED))
      end

      # helper methods
      def find_song(song_id)
        song = @songs_repo.find_by_id(song_id)
        raise SONG_NOT_EXISTS unless song

        song
      end

      def find_vocabs(song_id)
        vocabs = @vocabs_repo.for_song(song_id)
        raise VOCAB_NOT_EXISTS if vocabs.empty?

        vocabs
      end
    end
  end
end
