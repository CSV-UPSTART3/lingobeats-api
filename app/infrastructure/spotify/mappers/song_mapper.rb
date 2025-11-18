# frozen_string_literal: false

require 'yaml'

require_relative '../../../domain/songs/entities/song'
require_relative 'singer_mapper'

module LingoBeats
  module Spotify
    # Data Mapper: Spotify Track -> Song entity
    class SongMapper
      def initialize(client_id, client_secret, gateway_class = Spotify::Api)
        @gateway_class = gateway_class
        @gateway = @gateway_class.new(client_id, client_secret)
      end

      def search_songs_by_singer(query)
        data = @gateway.songs_data(category: 'singer', query: query, limit: 20)
        tracks = FieldExtractor.extract_search_track(data)
        self.class.build_entities(tracks)
      end

      def search_songs_by_song_name(query)
        data = @gateway.songs_data(category: 'song_name', query: query, limit: 20)
        tracks = FieldExtractor.extract_search_track(data)
        self.class.build_entities(tracks)
      end

      def search_popular_songs
        data = @gateway.billboard_data(limit: 10)
        tracks = FieldExtractor.extract_playlist_track(data)
        self.class.build_entities(tracks)
      end

      def fetch_song_info_by_id(song_id)
        data = @gateway.song_info(song_id: song_id)
        self.class.build_entity(data)
      end

      # --- class methods ---

      def self.build_entities(data)
        songs = Array(data).map { |track| build_entity(track) }
        Entity::Song.remove_unqualified_songs(songs.uniq)
      end

      def self.build_entity(data)
        DataMapper.new(data).build_entity
      end

      # Extract field from result
      module FieldExtractor
        module_function

        def extract_search_track(data)
          Array(data.dig('tracks', 'items'))
        end

        def extract_playlist_track(data)
          data['items'].map { |item| item['track'] }.compact
        end
      end

      # Extracts entity specific elements from data structure
      class DataMapper
        def initialize(data)
          @data = data
          @singer_mapper = SingerMapper.build_entities(@data['artists'])
        end

        def build_entity
          Entity::Song.new(
            name:, id:, uri:, external_url:,
            singers:,
            album_name:, album_id:, album_url:, album_image_url:,
            lyric: nil
          )
        end

        private

        def name = @data['name']
        def id = @data['id']
        def uri = @data['uri']
        def external_url = @data.dig('external_urls', 'spotify')

        def singers = @singer_mapper

        def album = @data['album']
        def album_name = album['name']
        def album_id = album['id']
        def album_url = album.dig('external_urls', 'spotify')
        def album_image_url = album.dig('images', 0, 'url')
      end
    end
  end
end
