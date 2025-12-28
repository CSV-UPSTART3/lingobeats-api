# frozen_string_literal: true

require 'erb'
require 'json'

module LingoBeats
  module Service
    # Service to generate learning materials for vocabularies in batches
    class MaterialGenerationService
      BATCH_SIZE = 5

      def initialize(
        mapper: LingoBeats::Gemini::VocabularyMapper.new(
          access_token: App.config.GEMINI_API_KEY
        )
      )
        @mapper = mapper
        @songs_repo = Repository::For.klass(Entity::Song)
        @vocabs_repo = Repository::For.klass(Entity::Vocabulary)
      end

      def call(song_id, &progress_callback)
        song = song_for(song_id)
        pending = pending_vocabs_for(song)

        processor.process(pending, song, progress_callback)
      rescue StandardError => error
        handle_error(error)
      end

      private

      def song_for(song_id)
        @songs_repo.find_by_id(song_id)
      end

      def pending_vocabs_for(song)
        vocabs = @vocabs_repo.for_song(song.id)
        PendingCollection.new(song, vocabs).pending
      end

      def processor
        BatchProcessor.new(
          mapper: @mapper,
          vocabs_repo: @vocabs_repo,
          validator: Validator::VocabularyInput,
          batch_size: BATCH_SIZE
        )
      end

      def handle_error(error)
        App.logger.error("[MaterialGenerationService] #{error.full_message}")
        raise error
      end

      # Renders the prompt for material generation
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

      # Collection helper to filter and order pending vocabularies
      class PendingCollection
        def initialize(song, vocabs, order_class: Songs::Services::LyricWordOrder)
          @song = song
          @vocabs = vocabs
          @order = order_class.new(song)
        end

        def pending
          filtered.each_with_index
                  .sort_by { |vocab, index| @order.position_for(vocab.original_word || vocab.name, offset + index) }
                  .map(&:first)
        end

        private

        def filtered
          @vocabs.select(&:material_blank?)
        end

        def offset
          @order.size
        end
      end

      # Helper to process batches and store generated materials
      class BatchProcessor
        def initialize(mapper:, vocabs_repo:, validator:, batch_size:)
          @mapper = mapper
          @vocabs_repo = vocabs_repo
          @validator = validator
          @batch_size = batch_size
        end

        def process(pending, song, progress_callback)
          BatchRun.new(pending, @batch_size, progress_callback).run do |batch|
            handle_batch(batch, song)
          end
        end

        private

        def handle_batch(batch, song)
          material_pairs(batch, song).each do |vocab, raw_material|
            next unless raw_material

            material_for_db = @validator.call(raw_hash: raw_material, word: vocab.name)
            next unless material_for_db

            save_vocab_material(vocab, material_for_db)
          end
        end

        def material_pairs(batch, song)
          prompt = MaterialGenerationService::PromptRenderer.call(batch:, song:)
          materials = @mapper.generate_and_parse(prompt)
          batch.zip(materials)
        end

        def save_vocab_material(vocab, material_for_db)
          updated_material_json = JSON.generate(material_for_db)
          @vocabs_repo.update_material(vocab.id, updated_material_json)
        end

        # Tracks batch progress and triggers callback updates
        class ProgressTracker
          def initialize(total, callback)
            @total = total
            @processed = 0
            @callback = callback
          end

          def advance(count)
            @processed += count
            notify
          end

          private

          def notify
            return unless @callback

            @callback.call(current: @processed, total: @total)
          end
        end

        # Iterator to handle pending vocab batches
        class PendingSequence
          include Enumerable

          def initialize(vocabs, batch_size)
            @vocabs = Array(vocabs)
            @batch_size = batch_size
          end

          def each(&block)
            return enum_for(:each) unless block

            @vocabs.each_slice(@batch_size, &block)
          end

          def empty?
            @vocabs.empty?
          end

          def total
            @vocabs.size
          end
        end

        # Coordinates iterating sequence and reporting progress
        class BatchRun
          def initialize(vocabs, batch_size, callback)
            @sequence = PendingSequence.new(vocabs, batch_size)
            @tracker = ProgressTracker.new(@sequence.total, callback) unless @sequence.empty?
          end

          def run
            return if @sequence.empty?

            @sequence.each do |batch|
              yield(batch)
              @tracker.advance(batch.size)
            end
          end
        end
      end
    end
  end
end
