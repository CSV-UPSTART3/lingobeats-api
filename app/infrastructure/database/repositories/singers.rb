# frozen_string_literal: true

module LingoBeats
  module Repository
    # Repository for Singers
    class Singers
      def self.find_or_create(singer_info)
        orm = LingoBeats::Database::SingerOrm
        orm.first(id: singer_info[:id]) || orm.create(singer_info) # 都是內建方法
      end

      def self.find_by_id(id)
        rebuild_entity Database::SingerOrm.first(id: id)
      end

      def self.find_name(name)
        rebuild_entity Database::SingerOrm.first(name: name)
      end

      def self.all
        rebuild_many Database::SingerOrm.all
      end

      def self.rebuild_entity(db_record)
        return nil unless db_record

        Entity::Singer.new(
          id: db_record.id,
          name: db_record.name,
          external_url: db_record.external_url
        )
      end

      def self.rebuild_many(db_records)
        db_records.map do |db_singer|
          Singers.rebuild_entity(db_singer)
        end
      end
    end
  end
end
