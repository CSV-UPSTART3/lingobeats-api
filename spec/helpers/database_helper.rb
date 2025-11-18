# frozen_string_literal: true

# Helper to clean database during test runs
module DatabaseHelper
  def self.wipe_database
    # Ignore foreign key constraints when wiping tables
    LingoBeats::App.db.run('PRAGMA foreign_keys = OFF')
    LingoBeats::Database::SingerOrm.map(&:destroy)
    LingoBeats::Database::SongOrm.map(&:destroy)
    LingoBeats::Database::LyricOrm.map(&:destroy)
    LingoBeats::Database::VocabularyOrm.map(&:destroy)
    LingoBeats::App.db[:songs_singers].delete if LingoBeats::App.db.table_exists?(:songs_singers)
    LingoBeats::App.db[:songs_vocabularies].delete if LingoBeats::App.db.table_exists?(:songs_vocabularies)
    LingoBeats::App.db.run('PRAGMA foreign_keys = ON')
  end
end
