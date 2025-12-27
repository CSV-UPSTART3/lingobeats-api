# frozen_string_literal: true

# Helper to clean database during test runs
module DatabaseHelper
  def self.wipe_database
    disable_foreign_keys
    wipe_join_tables
    wipe_domain_tables
    enable_foreign_keys
  end

  # Ignore foreign key constraints when wiping tables
  def self.disable_foreign_keys
    LingoBeats::App.db.run('PRAGMA foreign_keys = OFF')
  end

  def self.enable_foreign_keys
    LingoBeats::App.db.run('PRAGMA foreign_keys = ON')
  end

  def self.wipe_join_tables
    wipe_table(:songs_singers)
    wipe_table(:songs_vocabularies)
  end

  def self.wipe_table(table)
    return unless LingoBeats::App.db.table_exists?(table)

    LingoBeats::App.db[table].delete
  end

  def self.wipe_domain_tables
    domain_orms.each { |orm| orm.map(&:destroy) }
  end

  def self.domain_orms
    [
      LingoBeats::Database::SingerOrm,
      LingoBeats::Database::SongOrm,
      LingoBeats::Database::LyricOrm,
      LingoBeats::Database::VocabularyOrm
    ]
  end
end
