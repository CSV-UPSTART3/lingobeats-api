# frozen_string_literal: true

require 'dry/transaction'

module LingoBeats
  module Service
    # Transaction to store vocabularies for a song
    class AddVocabularies
      include Dry::Transaction

      step :split_and_evaluate
      step :process_vocabularies

      def initialize(vocab_repo: Repository::For.klass(Entity::Vocabulary))
        super()
        @vocab_repo = vocab_repo
      end

      VOCABULARY_EVAL_ERROR = 'Failed to evaluate words'
      VOCABULARY_PROCESS_ERROR = 'Failed to process vocabularies'
      DB_ERROR = 'Having trouble accessing the database'

      private

      def split_and_evaluate(song)
        return Success(song:, skip: true) if @vocab_repo.for_song(song.id).any?

        difficulties = song.evaluate_words

        Success(song:, difficulties:, skip: false)
      rescue StandardError => error
        App.logger.error("[AddVocabularies] #{VOCABULARY_EVAL_ERROR}: #{error.message}")
        Failure(Response::ApiResult.new(status: :internal_error, message: DB_ERROR))
      end

      def process_vocabularies(input)
        song = input[:song]
        return Success(Response::ApiResult.new(status: :ok, message: song)) if input[:skip]

        VocabularyProcessor.new(vocab_repo: @vocab_repo, song:, difficulties: input[:difficulties]).call

        Success(Response::ApiResult.new(status: :created, message: song))
      rescue StandardError => error
        App.logger.error("[AddVocabularies] #{VOCABULARY_PROCESS_ERROR}: #{error.message}")
        Failure(Response::ApiResult.new(status: :internal_error, message: DB_ERROR))
      end
    end

    # Helper class to process vocabularies
    class VocabularyProcessor
      def initialize(vocab_repo:, song:, difficulties:)
        @vocab_repo = vocab_repo
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
        existing = @vocab_repo.find_by_names(@difficulties.keys)
        existing.to_h { |vocab| [vocab.name, vocab.id] }
      end

      def build_new_entities(existing_map)
        words_to_create = @difficulties.reject { |word, level| existing_map.key?(word) || level.nil? }

        words_to_create.map do |word, level|
          Entity::Vocabulary.new(
            id: nil,
            name: word,
            level: level,
            material: nil
          )
        end
      end

      def link_vocabularies_to_song(new_entities, existing_map)
        vocab_ids = existing_map.values + create_vocabularies(new_entities)
        @vocab_repo.link_songs(@song.id, vocab_ids) unless vocab_ids.empty?
      end

      def create_vocabularies(entities)
        return [] if entities.empty?

        @vocab_repo.create_many(entities).map(&:id)
      end
    end
  end
end
