# frozen_string_literal: true

module LingoBeats
  module Repository
    # Repository for Lyrics
    class Lyrics
      def self.rebuild_value(db_record)
        return nil unless db_record

        Value::Lyric.new(text: db_record[:text] || db_record.text || nil)
      end

      def self.find_by_id(id)
        rebuild_value Database::LyricOrm.first(id: id)
      end

      def self.find_id_by_value(object)
        return nil unless object&.text

        object.checksum
      end

      def self.for_song(song_id)
        song = Database::SongOrm.first(id: song_id)
        return nil unless song

        lyric_id = song[:lyric_id]
        return nil unless lyric_id

        find_by_id(lyric_id)
      end

      # create lyric and link to song
      def self.find_or_create_by_value(object)
        return unless valid_lyric?(object)

        id = object.checksum
        insert_lyric_if_absent(id, object.text)
        id
      end

      def self.valid_lyric?(object)
        object&.text && object.english?
      end

      def self.song_id_present?(song_id)
        !song_id.to_s.strip.empty?
      end

      def self.valid_input?(song_id, lyric_object)
        song_id_present?(song_id) && valid_lyric?(lyric_object)
      end

      def self.insert_lyric_if_absent(id, text)
        Database::LyricOrm.dataset
                          .insert_conflict(target: :id)
                          .insert(id: id, text: text)
      end

      # attach lyric to song
      def self.attach_to_song(song_id, lyric_object)
        return unless valid_input?(song_id, lyric_object)

        lyric_id = find_or_create_by_value(lyric_object)
        update_song_lyric(song_id, lyric_id)
        lyric_object
      rescue Sequel::ForeignKeyConstraintViolation, Sequel::NoExistingObject
        nil
      end

      def self.update_song_lyric(song_id, lyric_id)
        Database::SongOrm.where(id: song_id).update(lyric_id: lyric_id)
      end
    end
  end
end
