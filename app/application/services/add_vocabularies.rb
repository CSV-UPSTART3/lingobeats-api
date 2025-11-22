# frozen_string_literal: true

require 'dry/transaction'

module LingoBeats
  module Service
    # Transaction to store vocabulary for a song
    class AddVocabularies
      include Dry::Transaction

      step :split_and_evaluate
      step :process_vocabularies

      def initialize(vocab_repo: Repository::For.klass(Entity::Vocabulary))
        super()
        @vocab_repo = vocab_repo
      end

      private

      # step 1. split song into words and evaluate their difficulty levels
      def split_and_evaluate(input)
        return Success(song: input, skip: true) if @vocab_repo.for_song(input.id).any?

        difficulties = input.evaluate_words
        Success(song: input, difficulties:)
      rescue StandardError => error
        Failure("Failed to evaluate words: #{error.message}")
      end

      # step 2. process vocabularies (check existing, create new, link to song)
      def process_vocabularies(input)
        return Success(input) if input[:skip]

        VocabularyProcessor.new(@vocab_repo, input).execute
        Success(input)
      rescue StandardError => error
        Failure("Failed to process vocabularies: #{error.message}")
      end
    end

    # Handles vocabulary creation and linking logic
    class VocabularyProcessor
      def initialize(vocab_repo, input)
        @vocab_repo = vocab_repo
        @song = input[:song]
        @difficulties = input[:difficulties]
      end

      def execute
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
        return if new_entities.empty? && existing_map.empty?

        newly_created_ids = create_vocabularies(new_entities)
        all_vocab_ids = existing_map.values + newly_created_ids
        @vocab_repo.link_songs(@song.id, all_vocab_ids)
      end

      def create_vocabularies(entities)
        return [] if entities.empty?

        created = @vocab_repo.create_many(entities)
        created.map(&:id)
      end
    end
  end
end
