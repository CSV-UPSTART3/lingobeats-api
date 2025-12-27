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
        mapper: Gemini::VocabularyMapper.new(access_token: App.config.GEMINI_API_KEY),
        material_job_queue: Messaging::MaterialJobQueue.new
      )
        super()
        @songs_repo = songs_repo
        @vocabs_repo = vocabs_repo
        @mapper = mapper
        @material_job_queue = material_job_queue
      end

      SONG_NOT_EXISTS = 'Cannot find the specified song'                   # → 404
      VOCAB_NOT_EXISTS = 'Cannot find the vocabularies in the song'        # → 404
      DB_ERROR = 'Having trouble accessing the database'                   # → 500
      MATERIAL_GENERATE_ERROR = 'Failed to generate learning materials'    # → 500

      MATERIAL_QUEUE_MESSAGES = {
        insert_to_queue: 'Material generation job queued',                 # → 202
        already_queued: 'Material generation job already in queue'         # → 202
      }.freeze

      private

      # step 1. fetch song + vocabs
      def fetch_data(input)
        song = find_song(input[:song_id])
        Success(input.merge(song: song, vocabs: find_vocabs(song.id)))
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
        return handle_no_pending_materials(input) if input[:pending_vocabs].empty?

        handle_pending_materials(input)
      rescue StandardError => error
        App.logger.error("[AddMaterial] generate materials error: #{error.full_message}")
        Failure(Response::ApiResult.new(status: :internal_error, message: MATERIAL_GENERATE_ERROR))
      end

      # step 4. build result to return
      # :reek:FeatureEnvy
      def build_result(input)
        Success(Response::ApiResult.new(status: input[:status], message: input[:message]))
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

      # if no pending vocabs, build the material entity to return
      # :reek:FeatureEnvy
      def build_material_entity(song)
        contents = @vocabs_repo.vocabs_content(song.id)
        Response::Material.new(song: song.name, contents: contents)
      end

      def handle_no_pending_materials(input)
        material = build_material_entity(input[:song])
        Success(input.merge(status: :ok, message: material))
      end

      def handle_pending_materials(input)
        song = input[:song]

        if Material::ProcessingLock.acquire?(song.id)
          # first time enqueue
          @material_job_queue.enqueue(song, input[:request_id])
          Success(input.merge(status: :processing, message: {
                                request_id: input[:request_id], msg: MATERIAL_QUEUE_MESSAGES[:insert_to_queue]
                              }))
        else
          App.logger.info("[AddMaterial] material job already queued for song=#{song.name}, song_id=#{song.id}")
          Success(input.merge(status: :processing, message: {
                                request_id: input[:request_id], msg: MATERIAL_QUEUE_MESSAGES[:already_queued]
                              }))
        end
      end
    end
  end
end
