# frozen_string_literal: true

require 'sequel'

module LingoBeats
  module Database
    # Object-Relational Mapper for Songs
    class SongOrm < Sequel::Model(:songs)
      unrestrict_primary_key

      many_to_many :singers,
                   class: :'LingoBeats::Database::SingerOrm',
                   join_table: :songs_singers,
                   left_key: :song_id, right_key: :singer_id

      many_to_many :vocabularies,
                   class: :'LingoBeats::Database::VocabularyOrm',
                   join_table: :songs_vocabularies,
                   left_key: :song_id, right_key: :vocabulary_id

      many_to_one :lyric,
                  class: :'LingoBeats::Database::LyricOrm',
                  key: :lyric_id

      plugin :timestamps, update_on_create: true
    end
  end
end
