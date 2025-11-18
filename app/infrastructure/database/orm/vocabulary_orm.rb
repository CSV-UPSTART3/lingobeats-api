# frozen_string_literal: true

require 'sequel'

module LingoBeats
  module Database
    # Object-Relational Mapper for Vocabularys
    class VocabularyOrm < Sequel::Model(:vocabularies)
      unrestrict_primary_key

      many_to_many :songs,
                   class: :'LingoBeats::Database::SongOrm',
                   join_table: :songs_vocabularies,
                   left_key: :vocabulary_id, right_key: :song_id

      plugin :timestamps, update_on_create: true
    end
  end
end
