# frozen_string_literal: true

require_relative 'helpers/spec_helper'
require_relative 'helpers/vcr_helper'
require_relative 'helpers/yaml_helper'

describe 'Tests Spotify API library' do
  before do
    VcrHelper.configure_vcr_for_spotify
  end

  after do
    VcrHelper.eject_vcr
  end

  describe 'Songs information searched by song name' do
    it 'HAPPY: should provide correct attributes of songs' do
      # check size, attribute, and important value
      results = LingoBeats::Spotify::SongMapper.new(SPOTIFY_CLIENT_ID, SPOTIFY_CLIENT_SECRET)
                                               .search_songs_by_song_name(SONG_NAME)
      results = YamlHelper.to_hash_array(results)
      _(results[0].size).must_equal CORRECT_RESULT_BY_SONG[0].size
      _(results[0].keys.sort).must_equal CORRECT_RESULT_BY_SONG[0].keys.sort
      # puts "RESULT id: #{results[0][:id].inspect}"
      # puts "RESULT name: #{results[0][:name].inspect}"
      # _(results[0][:name]).must_equal CORRECT_RESULT_BY_SONG[0][:name]
      _(results[0][:singers].class).must_equal CORRECT_RESULT_BY_SONG[0][:singers].class # Array
      _(results[0][:singers][0].class).must_equal CORRECT_RESULT_BY_SONG[0][:singers][0].class # Hash
      _(results[0][:singers][0].size).must_equal CORRECT_RESULT_BY_SONG[0][:singers][0].size
      _(results[0][:singers][0].keys.sort).must_equal CORRECT_RESULT_BY_SONG[0][:singers][0].keys.sort
    end
    it 'HAPPY: returns empty list when no songs matched' do
      results = LingoBeats::Spotify::SongMapper
                .new(SPOTIFY_CLIENT_ID, SPOTIFY_CLIENT_SECRET)
                .search_songs_by_song_name('totally-not-exist-zzz')
      results = YamlHelper.to_hash_array(results)

      _(results).must_be_kind_of Array
      _(results.length).must_equal 0
    end
    it 'SAD: raises ArgumentError when number of arguments is wrong' do
      _(proc do
        LingoBeats::Spotify::SongMapper.new('BAD_TOKEN').search_songs_by_song_name(SONG_NAME)
      end).must_raise ArgumentError
    end
    it 'SAD: raises ApiError when unauthorized' do
      _(proc do
        LingoBeats::Spotify::SongMapper.new('BAD_ID', 'BAD_SECRET').search_songs_by_song_name(SONG_NAME)
      end).must_raise LingoBeats::HttpHelper::Response::ApiError
    end
  end

  describe 'Songs information searched by singer' do
    it 'HAPPY: should provide correct attributes of multiple songs for a singer' do
      # check size and attributes
      results = LingoBeats::Spotify::SongMapper.new(SPOTIFY_CLIENT_ID, SPOTIFY_CLIENT_SECRET)
                                               .search_songs_by_singer(SINGER)
      results = YamlHelper.to_hash_array(results)

      _(results[0].size).must_equal CORRECT_RESULT_BY_SINGER[0].size
      _(results[0].keys.sort).must_equal CORRECT_RESULT_BY_SINGER[0].keys.sort
      # _(results[0][:name]).must_equal CORRECT_RESULT_BY_SINGER[0][:name]
      _(results[0][:singers].class).must_equal CORRECT_RESULT_BY_SONG[0][:singers].class # Array
      _(results[0][:singers][0].class).must_equal CORRECT_RESULT_BY_SONG[0][:singers][0].class # Hash
      _(results[0][:singers][0].size).must_equal CORRECT_RESULT_BY_SONG[0][:singers][0].size
      _(results[0][:singers][0].keys.sort).must_equal CORRECT_RESULT_BY_SONG[0][:singers][0].keys.sort
    end
    it 'HAPPY: returns empty list when no songs matched' do
      results = LingoBeats::Spotify::SongMapper
                .new(SPOTIFY_CLIENT_ID, SPOTIFY_CLIENT_SECRET)
                .search_songs_by_singer('totally-not-exist-zzz')
      results = YamlHelper.to_hash_array(results)

      _(results).must_be_kind_of Array
      _(results.length).must_equal 0
    end
    it 'SAD: raises ArgumentError when number of arguments is wrong' do
      _(proc do
        LingoBeats::Spotify::SongMapper.new('BAD_TOKEN').search_songs_by_singer(SINGER)
      end).must_raise ArgumentError
    end
    it 'SAD: raises ApiError when unauthorized' do
      _(proc do
        LingoBeats::Spotify::SongMapper.new('BAD_ID', 'BAD_SECRET').search_songs_by_singer(SINGER)
      end).must_raise LingoBeats::HttpHelper::Response::ApiError
    end
  end

  describe 'Songs information about billboard' do
    it 'HAPPY: should provide correct attributes of multiple songs for a singer' do
      # check size and attributes
      results = LingoBeats::Spotify::SongMapper.new(SPOTIFY_CLIENT_ID, SPOTIFY_CLIENT_SECRET)
                                               .search_popular_songs
      results = YamlHelper.to_hash_array(results)

      _(results.size).must_equal CORRECT_RESULT_BY_BILLBOARD.size
      _(results[0].size).must_equal CORRECT_RESULT_BY_BILLBOARD[0].size
      _(results[0].keys.sort).must_equal CORRECT_RESULT_BY_BILLBOARD[0].keys.sort
      # _(results[0][:name]).must_equal CORRECT_RESULT_BY_SINGER[0][:name]
      _(results[0][:singers].class).must_equal CORRECT_RESULT_BY_BILLBOARD[0][:singers].class # Array
      _(results[0][:singers][0].class).must_equal CORRECT_RESULT_BY_BILLBOARD[0][:singers][0].class # Hash
      _(results[0][:singers][0].size).must_equal CORRECT_RESULT_BY_BILLBOARD[0][:singers][0].size
      _(results[0][:singers][0].keys.sort).must_equal CORRECT_RESULT_BY_BILLBOARD[0][:singers][0].keys.sort
    end
    it 'SAD: raises ArgumentError when number of arguments is wrong' do
      _(proc do
        LingoBeats::Spotify::SongMapper.new('BAD_TOKEN').search_popular_songs
      end).must_raise ArgumentError
    end
    it 'SAD: raises ApiError when unauthorized' do
      _(proc do
        LingoBeats::Spotify::SongMapper.new('BAD_ID', 'BAD_SECRET').search_popular_songs
      end).must_raise LingoBeats::HttpHelper::Response::ApiError
    end
  end
end
