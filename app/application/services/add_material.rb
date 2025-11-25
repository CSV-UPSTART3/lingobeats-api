# frozen_string_literal: true

require 'dry/transaction'
require 'ostruct'

module LingoBeats
  module Service
    class AddMaterial
      include Dry::Transaction

      step :fetch_data
      step :build_prompt
      step :generate_material

      def initialize(songs_repo: Repository::For.klass(Entity::Song),
                     vocab_repo: Repository::For.klass(Entity::Vocabulary))
        super()
        @songs_repo = songs_repo
        @vocab_repo = vocab_repo
      end
      
      DB_ERROR = 'Having trouble accessing the database'
      PROMPT_BUILD_ERROR = "Failed to build prompt"
      MATERIAL_GENERATE_ERROR = 'Failed to generate learning materials'

      def fetch_data(input)
        song = @songs_repo.find_id(input[:song_id])
        vocabs = @vocab_repo.for_song(song.id)
        Success(input.merge(song: song, vocabs: vocabs))
      rescue => error
        App.logger.error("[AddMaterial] #{DB_ERROR}: #{error.message}")
        Failure(Response::ApiResult.new(status: :internal_error, message: DB_ERROR))
      end

      def build_prompt(input)
        song = input[:song]
        vocabs = input[:vocabs]

        prompts = vocabs.map do |vocab|
        PromptLoader.render(
          'material_prompt.erb',
          {
            word: vocab.name,
            level: vocab.level,
            song_name: song.name
          }
        )
        end
        Success(input.merge(prompts: prompts))
      rescue StandardError => error
        App.logger.error("[AddMaterial] #{PROMPT_BUILD_ERROR}: #{error.message}")
        Failure(Response::ApiResult.new(status: :internal_error, message: PROMPT_BUILD_ERROR))
      end

      def generate_material(input)
        song   = input[:song]
        # vocabs = input[:vocabs]

        generator = LingoBeats::Vocabularies::Services::GenerateMaterialsForSong.new(
          vocabulary_repo: @vocab_repo,
          mapper: LingoBeats::Gemini::VocabularyMapper.new(
            access_token: App.config.GEMINI_API_KEY
          )
        )

        vocabs = generator.call(song)

        Success(Response::ApiResult.new(status: :created,
          message: OpenStruct.new(
            song: input[:song].name,
            materials: vocabs.map { |vocab| JSON.parse(vocab.material) }
          )
        ))
      rescue StandardError => error
        App.logger.error("[AddMaterial] #{MATERIAL_GENERATE_ERROR}: #{error.message}")
        Failure(Response::ApiResult.new(status: :internal_error, message: MATERIAL_GENERATE_ERROR))
      end

      class PromptLoader
        def self.render(template_name, locals = {})
          path = File.join('app/application/services/prompts', template_name)
          template = File.read(path)
          ERB.new(template).result_with_hash(locals)
        end
      end
    end
  end
end
