# frozen_string_literal: true

require 'sequel'

Sequel.migration do
  change do
    create_table(:songs_vocabularies) do
      primary_key [:song_id, :vocabulary_id] # rubocop:disable Style/SymbolArray

      foreign_key :song_id, :songs,
                  key: :id, type: String, on_delete: :cascade

      foreign_key :vocabulary_id, :vocabularies,
                  key: :id,  on_delete: :cascade

      index [:song_id, :vocabulary_id] # rubocop:disable Style/SymbolArray
    end
  end
end
