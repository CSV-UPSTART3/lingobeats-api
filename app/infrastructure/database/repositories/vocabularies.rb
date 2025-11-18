# frozen_string_literal: true

require_relative '../orm/vocabulary_orm'
require_relative '../../gemini/mappers/vocabulary_mapper'
require_relative '../../../domain/vocabularies/entities/vocabulary'

module LingoBeats
  module Repository
    # Repository for Vocabulary Entities
    class Vocabularies
      # ORM mapping
      VocabularyOrm = LingoBeats::Database::VocabularyOrm

      # 取多筆
      def self.all
        rebuild_many(VocabularyOrm.all)
      end

      def self.latest(limit = 20)
        rows = VocabularyOrm.reverse_order(:id).limit(limit).all
        rebuild_many(rows)
      end

      # 查一筆
      def self.find_id(id)
        rec = VocabularyOrm.first(id: id)
        rebuild_entity(rec)
      end

      def self.for_song(song_id)
        song = LingoBeats::Database::SongOrm.first(id: song_id)
        return [] unless song

        rebuild_many(song.vocabularies)
      end

      def self.find_by_name(name)
        rec = VocabularyOrm.first(name: name)
        rebuild_entity(rec)
      end

      def self.create(entity)
        rec = VocabularyOrm.create(
          name: entity.name,
          level: entity.level,
          material: entity.material
        )
        rebuild_entity(rec)
      end

      def self.link_song(song_id, vocab_id)
        song = LingoBeats::Database::SongOrm.first(id: song_id)
        vocab = VocabularyOrm.first(id: vocab_id)
        return if song.vocabularies_dataset.where(id: vocab_id).any?

        song.add_vocabulary(vocab)
      end

      def self.update_material(id, material_hash)
        # puts material_hash.class
        rec = VocabularyOrm.first(id: id)
        rec.update(material: material_hash)
        rebuild_entity(rec)
      end

      # --- helpers ---
      def self.rebuild_many(db_records)
        Array(db_records).map { |rec| rebuild_entity(rec) }
      end
      private_class_method :rebuild_many

      def self.rebuild_entity(rec)
        return nil unless rec

        LingoBeats::Entity::Vocabulary.new(
          id: rec.id,
          name: rec.name,
          level: rec.level,
          material: rec.material   # String 或 nil
        )
      end
      private_class_method :rebuild_entity
    end
  end
end
