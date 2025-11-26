# frozen_string_literal: true

require 'sequel'

Sequel.migration do
  change do
    create_table(:lyrics) do
      String :id, primary_key: true
      String :text, null: true

      DateTime :created_at, null: false, default: Sequel::CURRENT_TIMESTAMP
    end

    alter_table(:songs) do
      add_column :lyric_id, String, null: true
      add_foreign_key [:lyric_id], :lyrics, key: :id, name: :fk_songs_lyric_id, on_delete: :set_null
      add_index :lyric_id
    end
  end
end
