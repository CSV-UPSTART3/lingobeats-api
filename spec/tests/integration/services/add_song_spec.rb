# frozen_string_literal: true

require_relative '../../../helpers/spec_helper'
require_relative '../../../helpers/vcr_helper'
require_relative '../../../helpers/database_helper'

describe 'AddSong Service Integration Test' do
    VcrHelper.setup_vcr

    before do
        VcrHelper.configure_vcr_for_spotify
        DatabaseHelper.wipe_database
    end

    after do
        VcrHelper.eject_vcr
    end

    describe 'Retrieve and store song' do
        it 'HAPPY: creates and stores song when not found in DB' do
            # GIVEN: a valid song that exists in remote provider
            songs = LingoBeats::Spotify::SongMapper.new(SPOTIFY_CLIENT_ID, SPOTIFY_CLIENT_SECRET)
                .search_songs_by_song_name(SONG_NAME)
            remote_song = songs.first

            # 關鍵：用 remote_song 真正的 Spotify track id
            song_id = remote_song.id  # 或 remote_song.id，看你的 entity 欄位

            # WHEN: the service is called with the request form object
            result = LingoBeats::Service::AddSong.new.call(song_id: song_id)

            unless result.success?
                puts "[DEBUG AddSong] status=#{result.failure.status}, message=#{result.failure.message.inspect}"
            end

            # THEN: the result should report success..
            _(result.success?).must_equal true

            # ..and provide a song entity with the right details
            song = result.value!.message

            _(song.id).must_equal remote_song.id
            _(song.name).must_equal remote_song.name
            _(song.uri).must_equal remote_song.uri
            _(song.external_url).must_equal remote_song.external_url
            _(song.album_id).must_equal remote_song.album_id
            _(song.album_name).must_equal remote_song.album_name
            _(song.album_url).must_equal remote_song.album_url
            _(song.album_image_url).must_equal remote_song.album_image_url
        end

        it 'HAPPY: returns existing song when already in DB' do
            # GIVEN: a song already stored in database
            songs_repo = LingoBeats::Repository::For.klass(LingoBeats::Entity::Song)
            singer_entity = LingoBeats::Entity::Singer.new(
                id: 'singer123',
                name: 'Test Singer',
                uri: 'spotify:artist:test',
                external_url: 'https://open.spotify.com/artist/test'
            )

            song_entity = LingoBeats::Entity::Song.new(
                id: '3XVozq1aeqsJwpXrEZrDJ9',
                name: 'Test Song',
                uri: 'spotify:track:test',
                external_url: 'https://open.spotify.com/track/test',
                album_id: 'test_album',
                album_name: 'Test Album',
                album_url: 'https://open.spotify.com/album/test',
                album_image_url: 'https://example.com/image.jpg',
                lyric: nil,
                singers: singer_entity ? [singer_entity] : []
            )

            stored_song = songs_repo.create(song_entity)

            # WHEN: the service is called again with the same request
            result = LingoBeats::Service::AddSong.new.call(song_id: '3XVozq1aeqsJwpXrEZrDJ9')

            # THEN: the result should report success..
            _(result.success?).must_equal true

            # ..and return the same song record from database
            song = result.value!.message
            _(song.id).must_equal song_entity.id
            _(song.name).must_equal song_entity.name
            _(song.uri).must_equal song_entity.uri
            _(song.external_url).must_equal song_entity.external_url
            _(song.album_id).must_equal song_entity.album_id
            _(song.album_name).must_equal song_entity.album_name
            _(song.album_url).must_equal song_entity.album_url
            _(song.album_image_url).must_equal song_entity.album_image_url
        end

        # it 'SAD: fails gracefully for non-existent song' do
        #     # WHEN: the service is called with non-existent song details
        #     result = LingoBeats::Service::AddSong.new.call('this-song-does-not-exist-xyz')

        #     # THEN: the service should report failure with an error message
        #     _(result.success?).must_equal false
        #     _(result.failure.message.downcase).must_include 'not find'
        # end
    end
end
