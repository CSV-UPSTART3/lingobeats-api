# frozen_string_literal: true

require_relative '../orm/vocabulary_orm'
require_relative '../../gemini/mappers/vocabulary_mapper'
require_relative '../../../domain/vocabularies/entities/vocabulary'

module LingoBeats
  module Repository
    # Repository for Vocabulary Entities
    class Vocabularies
      # 取多筆
      def self.all
        rows = LingoBeats::Database::VocabularyOrm.all
        rebuild_many(rows)
      end

      def self.latest(limit = 20)
        LingoBeats::Database::VocabularyOrm.reverse_order(:id)
                                           .limit(limit).all
                                           .map { |rec| rebuild_entity(rec) }
      end

      # 查一筆
      def self.find_id(id)
        rec = LingoBeats::Database::VocabularyOrm.first(id: id)
        rebuild_entity(rec)
      end

      def self.find_by_song_id(song_id)
        rec = LingoBeats::Database::VocabularyOrm.where(song_id: song_id)
                                                 .order(Sequel.desc(:id)).first
        rebuild_entity(rec)
      end

      # 新增（由 Domain Entity 建立）
      def self.create(entity)
        rec = LingoBeats::Database::VocabularyOrm.create(
          song_id: entity.song_id,
          level: entity.level,
          content: entity.content # JSON 字串
        )
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
          song_id: rec.song_id,
          level: rec.level,
          content: rec.content
        )
      end
      private_class_method :rebuild_entity
    end
  end
end
