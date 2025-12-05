# frozen_string_literal: true

require 'dry/transaction'
require 'ostruct'
require 'json'
require 'erb'

module LingoBeats
  module Service
    # Transaction to add learning materials for vocabularies of a song
    class AddMaterial
      include Dry::Transaction

      BATCH_SIZE = 10

      step :fetch_data
      step :find_pending
      step :generate_for_pending
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
      def generate_for_pending(input)
        pending_vocabs = input[:pending_vocabs]
        return Success({ song: input[:song] }) if pending_vocabs.empty?

        pending_vocabs.each_slice(BATCH_SIZE).flat_map { |batch| generate_batch_materials(batch, input[:song]) }

        Success({ song: input[:song] })
      rescue StandardError => error
        App.logger.error("[AddMaterial] generate materials error: #{error.full_message}")
        Failure(Response::ApiResult.new(status: :internal_error, message: MATERIAL_GENERATE_ERROR))
      end

      # step 4. build API result (all vocabs)
      def build_result(input)
        result = Response::Material.new(
          song: input[:song].name,
          contents: @vocabs_repo.vocabs_content(input[:song].id)
        )

        Success(Response::ApiResult.new(status: :created, message: result))
      rescue StandardError => error
        App.logger.error("[AddMaterial] build result error: #{error.full_message}")
        Failure(Response::ApiResult.new(status: :internal_error, message: DB_ERROR))
      end

      # helper methods
      # for each batch of vocabs, generate materials and update them in the repo
      def generate_batch_materials(batch, song)
        prompt = PromptRenderer.call(batch: batch, song: song)
        materials = @mapper.generate_and_parse(prompt)

        batch.zip(materials).filter_map do |vocab, raw_material|
          # puts "[DEBUG] vocab=#{vocab.name}, level=#{vocab.level}"
          material_for_db = validate_vocab_format(vocab, raw_material)
          next unless material_for_db

          save_vocab_material(vocab, material_for_db)
        end
      end

      def validate_vocab_format(vocab, raw_material)
        return unless raw_material

        Validator::VocabularyInput.call(
          raw_hash: raw_material,
          word: vocab.name
        )
      end

      def save_vocab_material(vocab, material_for_db)
        attrs = vocab.to_attr_hash.merge(
          material: JSON.generate(material_for_db)
        )

        updated = Entity::Vocabulary.new(attrs)
        @vocabs_repo.update_material(updated.id, updated.material)
        updated
      end

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

      # helper class to render Gemini prompt
      class PromptRenderer
        TEMPLATE_PATH = 'app/application/services/prompts/material_prompt.erb'

        def self.call(batch:, song:)
          pairs = batch.map { |vocab| { word: vocab.name, level: vocab.level } }

          template = File.read(TEMPLATE_PATH)

          ERB.new(template).result_with_hash(
            vocab_pairs: pairs,
            song_name: song.name
          )
        end
      end
    end
  end
end
