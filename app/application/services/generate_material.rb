# frozen_string_literal: true

require 'erb'
require 'json'

module LingoBeats
  module Service
    class MaterialGenerationService
      BATCH_SIZE = 10

      def initialize(
        mapper: LingoBeats::Gemini::VocabularyMapper.new(
          access_token: App.config.GEMINI_API_KEY
        )
      )
        @mapper = mapper
        @songs_repo = Repository::For.klass(Entity::Song)
        @vocabs_repo = Repository::For.klass(Entity::Vocabulary)
      end

      def call(song_id)
        song   = @songs_repo.find_by_id(song_id)
        vocabs = @vocabs_repo.for_song(song_id)

        pending = vocabs.select(&:material_blank?)
        total = pending.size
        return if total.zero?

        processed = 0

        pending.each_slice(BATCH_SIZE) do |batch|
          generate_batch_materials(batch, song)
          processed += batch.size
          
          yield(current: processed, total: total) if block_given?
        end

      rescue StandardError => error
        App.logger.error("[MaterialGenerationService] #{error.full_message}")
        raise error # let worker retry
      end

      private

      def generate_batch_materials(batch, song)
        prompt = PromptRenderer.call(batch: batch, song: song)
        materials = @mapper.generate_and_parse(prompt)

        batch.zip(materials).each do |vocab, raw_material|
          next unless raw_material
          material_for_db = validate_vocab_format(vocab, raw_material)
          next unless material_for_db
          save_vocab_material(vocab, material_for_db)
        end
      end

      def validate_vocab_format(vocab, raw_material)
        Validator::VocabularyInput.call(
          raw_hash: raw_material,
          word: vocab.name
        )
      end

      def save_vocab_material(vocab, material_for_db)
        updated_material_json = JSON.generate(material_for_db)
        @vocabs_repo.update_material(vocab.id, updated_material_json)
      end

      class PromptRenderer
        TEMPLATE_PATH = 'app/application/services/prompts/material_prompt.erb'

        def self.call(batch:, song:)
          pairs = batch.map { |v| { word: v.name, level: v.level } }
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
