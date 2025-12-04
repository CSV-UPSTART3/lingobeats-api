# frozen_string_literal: false

require_relative '../../../helpers/spec_helper'
require_relative '../../../helpers/vcr_helper'
require_relative '../../../helpers/yaml_helper'
require_relative '../../../helpers/database_helper'

describe 'Integration Tests of Spotify API and Database' do
  before do
    VcrHelper.configure_vcr_for_spotify
    DatabaseHelper.wipe_database
  end

  after do
    VcrHelper.eject_vcr
  end

  describe 'Retrieve and store songs' do
    it 'HAPPY: should retrieve song data from Spotify and store to DB' do
      # get data from Spotify API
      results = LingoBeats::Spotify::SongMapper
                .new(SPOTIFY_CLIENT_ID, SPOTIFY_CLIENT_SECRET)
                .search_songs_by_song_name(SONG_NAME)
      lyric_mapper = LingoBeats::Genius::LyricMapper
                     .new(GENIUS_CLIENT_ACCESS_TOKEN)

      # puts results.first # is an entity
      # results = YamlHelper.to_hash_array(results)

      # store to database
      song_entity = results.first
      song_repo = LingoBeats::Repository::For.entity(song_entity)
      lyric_repo = LingoBeats::Repository::For.klass(LingoBeats::Value::Lyric)

      # if song does not exist in DB
      # 先把歌（跟歌手關聯）寫進 songs 資料表
      rebuilt = song_repo.create(song_entity)

      # 再去拿歌詞，然後再存入 lyrics
      first_singer_name = song_entity.singers.first&.name
      lyric_value_object = lyric_mapper.lyrics_for(
        song_name: song_entity.name,
        singer_name: first_singer_name
      )

      # lyric_entity = LingoBeats::Value::Lyric.new(
      #   text: lyric_text
      # song_id: song_entity.id,
      # lyric: lyric_text
      # )
      LingoBeats::Repository::Lyrics.attach_to_song(song_entity.id, lyric_value_object)
      # lyric_repo.create(lyric_entity)

      # puts rebuilt
      # puts rebuilt.singers
      # puts rebuilt.lyric # to-do
      # puts rebuilt.name
      # puts rebuilt == results.first

      # verify stored data
      _(rebuilt.id).must_equal results.first.id
      _(rebuilt.name).must_equal results.first.name
      _(rebuilt.uri).must_equal results.first.uri
      _(rebuilt.external_url).must_equal results.first.external_url
      _(rebuilt.album_id).must_equal results.first.album_id
      _(rebuilt.album_name).must_equal results.first.album_name
      _(rebuilt.album_url).must_equal results.first.album_url
      _(rebuilt.album_image_url).must_equal results.first.album_image_url
      rebuilt.singers.each_with_index do |singer, index|
        _(singer.id).must_equal results.first.singers[index].id
        _(singer.name).must_equal results.first.singers[index].name
        _(singer.external_url).must_equal results.first.singers[index].external_url
      end
      # verify stored lyric
      stored_lyric = lyric_repo.for_song(song_entity.id)
      # puts stored_lyric.inspect
      _(stored_lyric).wont_be_nil
      # _(stored_lyric.lyric).must_equal lyric_text
      # _(stored_lyric.song_id).must_equal song_entity.id
      _(stored_lyric.text[0..30]).must_equal lyric_value_object.text[0..30] # 前幾個字比對，避免長度差異
    end
  end
end
