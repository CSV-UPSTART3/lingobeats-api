# frozen_string_literal: true

require 'sequel'

module LingoBeats
  module Database
    # Object-Relational Mapper for Materials
    class VocabularyOrm < Sequel::Model(:materials)
      unrestrict_primary_key

      # many_to_one :song,
      #             class: :'LingoBeats::Database::SongOrm',
      #             key: :song_id

      plugin :timestamps, update_on_create: true
    end
  end
end
