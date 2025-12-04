# frozen_string_literal: true

require 'dry/transaction'

module LingoBeats
  module Service
    # Transaction to store vocabularies for a song
    class AddVocabularies
      include Dry::Transaction

      step :split_and_evaluate
      step :process_vocabularies

      VOCABULARY_EVAL_ERROR = 'Failed to evaluate words'
      VOCABULARY_PROCESS_ERROR = 'Failed to process vocabularies'
      DB_ERROR = 'Having trouble accessing the database'
      #DB_ERROR = 'ADD_VOCABS_DB_ERROR'

      def initialize(vocabs_repo: Repository::For.klass(Entity::Vocabulary))
        super()
        @vocabs_repo = vocabs_repo
      end

      private

      def split_and_evaluate(song)
        return Success(song:, skip: true) if @vocabs_repo.for_song(song.id).any?

        difficulties = song.evaluate_words

        Success(song:, difficulties:, skip: false)
      rescue StandardError => error
        handle_error(VOCABULARY_EVAL_ERROR, error)
      end

      def process_vocabularies(input)
        return Success(Response::ApiResult.new(status: :ok, message: input[:song])) if input[:skip]

        process_new_vocabularies(input)
      rescue StandardError => error
        handle_error(VOCABULARY_PROCESS_ERROR, error)
      end

      # helper method to process new vocabularies
      def process_new_vocabularies(input)
        song = input[:song]

        VocabularyProcessor.new(
          vocabs_repo: @vocabs_repo,
          song:,
          difficulties: input[:difficulties]
        ).call

        Success(Response::ApiResult.new(status: :created, message: song))
      end

      # helper method to handle errors
      def handle_error(message, error)
        App.logger.error("[AddVocabularies] #{message}: #{error.full_message}")
        Failure(Response::ApiResult.new(status: :internal_error, message: DB_ERROR))
      end
    end

    # Helper class to process vocabularies
    class VocabularyProcessor
      def initialize(vocabs_repo:, song:, difficulties:)
        @vocabs_repo = vocabs_repo
        @song = song
        @difficulties = difficulties
      end

      def call
        existing_map = fetch_existing_vocabularies
        new_entities = build_new_entities(existing_map)
        link_vocabularies_to_song(new_entities, existing_map)
      end

      private

      def fetch_existing_vocabularies
        existing = @vocabs_repo.find_by_names(@difficulties.keys)
        existing.to_h { |vocab| [vocab.name, vocab.id] }
      end

      def build_new_entities(existing_map)
        Vocabularies::VocabularyBuilder.build_from_difficulties(
          @difficulties,
          existing_names: existing_map.keys
        )
      end

      def link_vocabularies_to_song(new_entities, existing_map)
        vocab_ids = existing_map.values + create_vocabularies(new_entities)
        @vocabs_repo.link_songs(@song.id, vocab_ids) unless vocab_ids.empty?
      end

      def create_vocabularies(entities)
        return [] if entities.empty?

        @vocabs_repo.create_many(entities).map(&:id)
      end
    end
  end
end
