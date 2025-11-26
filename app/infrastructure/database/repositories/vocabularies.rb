# frozen_string_literal: true

require_relative '../orm/vocabulary_orm'
require_relative '../../gemini/mappers/vocabulary_mapper'
require_relative '../../../domain/vocabularies/entities/vocabulary'

module LingoBeats
  module Repository
    # Repository for Vocabulary Entities
    class Vocabularies
      # ORM mapping
      VocabularyOrm = Database::VocabularyOrm

      # 取多筆
      def self.all
        rebuild_many(VocabularyOrm.all)
      end

      def self.latest(limit = 20)
        rows = VocabularyOrm.reverse_order(:id).limit(limit).all
        rebuild_many(rows)
      end

      # 查一筆
      def self.find_by_id(id)
        rec = VocabularyOrm.first(id: id)
        rebuild_entity(rec)
      end

      def self.for_song(song_id)
        song = Database::SongOrm.first(id: song_id)
        return [] unless song

        rebuild_many(song.vocabularies)
      end

      def self.find_by_name(name)
        rec = VocabularyOrm.first(name: name)
        rebuild_entity(rec)
      end

      def self.find_by_names(names)
        VocabularyOrm.where(name: names).all.map { |rec| rebuild_entity(rec) }
      end

      def self.create(entity)
        rec = VocabularyOrm.create(
          name: entity.name,
          level: entity.level,
          material: entity.material
        )
        rebuild_entity(rec)
      end

      def self.create_many(entities)
        # 用 transaction 包起來，避免一半成功一半失敗
        VocabularyOrm.db.transaction do
          entities.map do |ent|
            rec = VocabularyOrm.create(
              name: ent.name,
              level: ent.level,
              material: ent.material
            )
            rebuild_entity(rec)
          end
        end
      end

      def self.link_song(song_id, vocab_id)
        song = Database::SongOrm.first(id: song_id)
        vocab = VocabularyOrm.first(id: vocab_id)
        return if song.vocabularies_dataset.where(id: vocab_id).any?

        song.add_vocabulary(vocab)
      end

      def self.link_songs(song_id, vocab_ids)
        song = Database::SongOrm.first(id: song_id)
        existing_vocab_ids = song.vocabularies_dataset.select(:id).map(:id)
        new_vocab_ids = vocab_ids - existing_vocab_ids
        return if new_vocab_ids.empty?

        new_vocab_ids.each do |vocab_id|
          vocab = VocabularyOrm.first(id: vocab_id)
          song.add_vocabulary(vocab) if vocab
        end
      end

      def self.update_material(id, material_hash)
        # puts material_hash.class
        rec = VocabularyOrm.first(id: id)
        rec.update(material: material_hash)
        rebuild_entity(rec)
      end

      def self.incomplete_material?(song_id)
        vocabs = for_song(song_id)
        return true if vocabs.empty?

        vocabs.any? { |vocab| vocab.material.to_s.strip.empty? }
      end

      def self.vocabs_content(id)
        vocabs = for_song(id)
        vocabs.map { |vocab| JSON.parse(vocab.material) }.compact
      end

      # --- helpers ---
      def self.rebuild_many(db_records)
        Array(db_records).map { |rec| rebuild_entity(rec) }
      end

      def self.rebuild_entity(rec)
        return nil unless rec

        Entity::Vocabulary.new(
          id: rec.id,
          name: rec.name,
          level: rec.level,
          material: rec.material # String 或 nil
        )
      end
      private_class_method :rebuild_many, :rebuild_entity
    end
  end
end
