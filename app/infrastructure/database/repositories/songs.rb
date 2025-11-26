# frozen_string_literal: true

require_relative 'singers'
require_relative 'lyrics'
require_relative '../../spotify/mappers/song_mapper' # for SongMapper

module LingoBeats
  module Repository
    # Repository for Song Entities
    class Songs
      CONFIG = LingoBeats::App.config

      def self.find_or_create(song_info)
        orm = LingoBeats::Database::SongOrm
        orm.first(uri: song_info[:uri]) || orm.create(song_info)
      end

      def self.all
        rows = Database::SongOrm.all
        return rebuild_many(rows) unless rows.empty?

        seed_from_spotify
        # rebuild_many(Database::SongOrm.all)
      end

      def self.rebuild_many(db_records)
        db_records.map { |record| rebuild_entity(record) }
      end

      def self.find_by_id(id)
        db_record = Database::SongOrm.first(id: id)
        rebuild_entity(db_record)
      end

      def self.rebuild_entity(db_record)
        return nil unless db_record

        EntityBuilder.new(db_record).build
      end

      def self.create(entity)
        raise 'Song already exists' if find_by_id(entity.id)

        # return find_by_id(entity.id) if find_by_id(entity.id)
        db_song = PersistSong.new(entity).call
        rebuild_entity(db_song)
      end

      def self.ensure_song_exists(song_id)
        find_by_id(song_id) || begin
          mapper = build_spotify_mapper
          song_info = mapper.fetch_song_info_by_id(song_id)
          create(song_info) if song_info
        end
      end

      def self.seed_from_spotify
        # 初始化 mapper
        mapper = build_spotify_mapper

        # 從 Spotify 抓熱門歌:回來是一個 [Entity::Song, ...]
        songs_from_api = mapper.display_popular_songs

        # 把每一首歌存進 DB（含 singers/lyric(nil)）
        songs_from_api.each do |song_entity|
          create(song_entity)
        end

        songs_from_api
      end

      def self.build_spotify_mapper
        LingoBeats::Spotify::SongMapper.new(
          CONFIG.SPOTIFY_CLIENT_ID,
          CONFIG.SPOTIFY_CLIENT_SECRET
        )
      end

      # return lyric value object if exists
      def self.find_lyric_in_database(song_id:)
        find_by_id(song_id)&.lyric
      end

      # fetch lyric from Genius API
      def self.fetch_lyric(song_name:, singer_name:)
        lyric_mapper = Genius::LyricMapper.new(CONFIG.GENIUS_CLIENT_ACCESS_TOKEN)
        lyric_mapper.lyrics_for(song_name: song_name, singer_name: singer_name)
      end

      # attach lyric value object to song in database, return updated lyric vo
      def self.attach_lyric(song_id:, lyric_vo:)
        lyric_repo = Repository::For.klass(Value::Lyric)
        lyric_repo.attach_to_song(song_id, lyric_vo)
        find_lyric_in_database(song_id: song_id)
      rescue StandardError => error
        App.logger.error("Failed to store lyric to database: #{error.full_message}")
        raise 'Error in connecting to database.'
      end

      # Helper class to rebuild entity from DB
      class EntityBuilder
        SIMPLE_FIELDS = %i[id name uri external_url album_id
                           album_name album_url album_image_url].freeze

        def initialize(db_record)
          @db_record = db_record
        end

        def build
          Entity::Song.new(**attributes)
        end

        private

        def attributes
          simple_attributes.merge(relationship_attributes)
        end

        def simple_attributes
          SIMPLE_FIELDS.each_with_object({}) do |field, attrs|
            attrs[field] = @db_record.public_send(field)
          end
        end

        def relationship_attributes
          lyric_record = @db_record.lyric
          {

            lyric: lyric_record ? Lyrics.rebuild_value(lyric_record) : nil,
            singers: @db_record.singers ? Singers.rebuild_many(@db_record.singers) : []
          }
        end
      end

      # helper class to persist song, lyric, singers
      class PersistSong
        def initialize(entity)
          @entity = entity
        end

        def create_song
          Database::SongOrm.create(@entity.to_attr_hash)
        end

        def call
          db_song = create_song
          relation = BuildRelationships.new(@entity, db_song)
          relation.attach_singers
          relation.attach_lyric
          db_song
        end

        # helper class to build relationships
        class BuildRelationships
          def initialize(entity, db_song)
            @entity = entity
            @db_song = db_song
          end

          def attach_singers
            Array(@entity.singers).each do |singer|
              db_singer = Singers.find_or_create(singer.to_attr_hash)
              @db_song.add_singer(db_singer) unless @db_song.singers.include?(db_singer)
            end
          end

          def attach_lyric
            object = @entity.lyric
            return unless object

            lyric_id = Lyrics.attach_to_song(@db_song.id, object)
            @db_song.refresh if lyric_id
          end
        end
      end
    end
  end
end
