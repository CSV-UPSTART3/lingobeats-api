# frozen_string_literal: true

require 'json'
require_relative '../orm/vocabulary_orm'
require_relative '../../gemini/mappers/vocabulary_mapper'
require_relative '../../../domain/vocabularies/entities/vocabulary'

module LingoBeats
  module Repository
    # Repository for Vocabulary entities (DB access + entity rebuild + linking).
    class Vocabularies
      VocabularyOrm = Database::VocabularyOrm

      # 取多筆
      def self.all
        VocabulariesSupport.rebuild_many(VocabularyOrm.all)
      end

      def self.latest(limit = 20)
        VocabulariesSupport.rebuild_many(VocabularyOrm.reverse_order(:id).limit(limit).all)
      end

      # 查一筆
      def self.find_by_id(id)
        VocabulariesSupport.rebuild_entity(VocabularyOrm.first(id: id))
      end

      def self.for_song(song_id)
        VocabulariesSupport.with_song(song_id) do |song|
          VocabulariesSupport.rebuild_many(song.vocabularies)
        end || []
      end

      def self.find_by_name(name)
        VocabulariesSupport.rebuild_entity(VocabularyOrm.first(name: name))
      end

      def self.find_by_ids(ids)
        ordered_ids = VocabulariesSupport.normalize_ids(ids)
        return [] if ordered_ids.empty?

        VocabulariesSupport.ordered_entities(VocabularyOrm, ordered_ids)
      end

      def self.find_by_names(names)
        VocabularyOrm.where(name: names).all.map { |rec| VocabulariesSupport.rebuild_entity(rec) }.compact
      end

      def self.create(entity)
        rec = VocabularyOrm.create(
          name: entity.name,
          original_word: entity.original_word,
          level: entity.level,
          material: entity.material
        )
        VocabulariesSupport.rebuild_entity(rec)
      end

      def self.create_many(entities)
        VocabularyOrm.db.transaction do
          entities.map { |ent| create_from_entity(ent) }
        end
      end

      def self.link_song(song_id, vocab_id)
        VocabulariesSupport.with_song(song_id) do |song|
          next if song.vocabularies_dataset.where(id: vocab_id).any?

          vocab = VocabularyOrm.first(id: vocab_id)
          song.add_vocabulary(vocab) if vocab
        end
      end

      def self.link_songs(song_id, vocab_ids)
        VocabulariesSupport.with_song(song_id) do |song|
          new_ids = VocabulariesSupport.new_vocab_ids_for(song, vocab_ids)
          VocabulariesSupport.add_vocabularies(VocabularyOrm, song, new_ids) unless new_ids.empty?
        end
      end

      def self.update_material(id, material_hash)
        rec = VocabularyOrm.first(id: id)
        return nil unless rec

        rec.update(material: material_hash)
        VocabulariesSupport.rebuild_entity(rec)
      end

      def self.incomplete_material?(song_id)
        vocabs = for_song(song_id)
        return true if vocabs.empty?

        vocabs.any? { |vocab| vocab.material.to_s.strip.empty? }
      end

      def self.vocabs_content(song_id)
        for_song(song_id).filter_map { |vocab| VocabulariesSupport.material_payload(vocab) }
      end

      def self.contents_by_ids(ids)
        find_by_ids(ids).filter_map { |vocab| VocabulariesSupport.material_payload(vocab) }
      end

      def self.create_from_entity(ent)
        rec = VocabularyOrm.create(
          name: ent.name,
          original_word: ent.original_word,
          level: ent.level,
          material: ent.material
        )
        VocabulariesSupport.rebuild_entity(rec)
      end
      private_class_method :create_from_entity
    end

    # Helper functions used by the Vocabularies repository (rebuild, ordering, linking).
    module VocabulariesSupport
      module_function

      def rebuild_many(db_records)
        Array(db_records).map { |rec| rebuild_entity(rec) }
      end

      def rebuild_entity(rec)
        return nil unless rec

        Entity::Vocabulary.new(
          id: rec.id,
          name: rec.name,
          level: rec.level,
          original_word: rec.original_word,
          material: rec.material
        )
      end

      def material_payload(vocab)
        return nil unless vocab.material && !vocab.material.empty?

        material = JSON.parse(vocab.material)
        material.merge(
          'id'          => vocab.id,
          'word'        => vocab.name,
          'origin_word' => vocab.original_word,
          'level'       => vocab.level
        )
      end

      def normalize_ids(ids)
        Array(ids).map(&:to_i).uniq
      end

      def ordered_entities(vocabulary_orm, ordered_ids)
        records = vocabulary_orm.where(id: ordered_ids).all
        entities = rebuild_many(records)
        entity_map = entities.to_h { |vocab| [vocab.id, vocab] }
        ordered_ids.filter_map { |id| entity_map[id] }
      end

      def with_song(song_id)
        song = Database::SongOrm.first(id: song_id)
        return nil unless song

        yield song
      end

      def new_vocab_ids_for(song, vocab_ids)
        existing_ids = song.vocabularies_dataset.select(:id).map(:id)
        Array(vocab_ids) - existing_ids
      end

      def add_vocabularies(vocabulary_orm, song, vocab_ids)
        vocab_ids.each do |vocab_id|
          vocab = vocabulary_orm.first(id: vocab_id)
          song.add_vocabulary(vocab) if vocab
        end
      end
    end
  end
end
