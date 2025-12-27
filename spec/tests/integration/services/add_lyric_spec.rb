# frozen_string_literal: true

require_relative '../../../helpers/spec_helper'
require_relative '../../../helpers/vcr_helper'
require_relative '../../../helpers/database_helper'

describe 'AddLyric Service Integration Test' do
  VcrHelper.setup_vcr

  before do
    DatabaseHelper.wipe_database
  end

  after do
    VcrHelper.eject_vcr
  end

  it 'HAPPY: fetches lyric from Genius, stores it,and returns :ok with lyric text' do
    songs_repo = LingoBeats::Repository::For.klass(LingoBeats::Entity::Song)

    # ===== spotify vcr =====
    VCR.use_cassette(
      'spotify_api',
      record: :new_episodes,
      match_requests_on: %i[method uri headers]
    ) do
      add_song_result = LingoBeats::Service::AddSong.new.call(song_id: SONG_ID)
      _(add_song_result.success?).must_equal true
    end

    # DB 有歌，沒有 lyric
    _(songs_repo.find_by_id(SONG_ID)).wont_be_nil
    _(songs_repo.find_lyric_in_database(song_id: SONG_ID)).must_be_nil

    # ===== genius vcr =====
    VCR.use_cassette(
      'genius_api',
      record: :new_episodes,
      match_requests_on: %i[method uri headers]
    ) do
      service = LingoBeats::Service::AddLyric.new
      result  = service.call(song_id: SONG_ID)

      _(result.success?).must_equal true
      api = result.value!

      # :ok：message is lyric
      _(api.status).must_equal :ok

      lyric = api.message
      _(lyric).wont_be_nil
      _(lyric.respond_to?(:text)).must_equal true
      _(lyric.text.to_s.strip.empty?).must_equal false
    end

    stored_lyric = songs_repo.find_lyric_in_database(song_id: SONG_ID)
    _(stored_lyric).wont_be_nil
    _(stored_lyric.text.to_s.strip.empty?).must_equal false
  end

  it 'HAPPY: reuses existing lyric from DB when lyric already exists' do
    songs_repo = LingoBeats::Repository::For.klass(LingoBeats::Entity::Song)

    # ===== spotify vcr =====
    VCR.use_cassette(
      'spotify_api',
      record: :new_episodes,
      match_requests_on: %i[method uri headers]
    ) do
      add_song_result = LingoBeats::Service::AddSong.new.call(song_id: SONG_ID)
      _(add_song_result.success?).must_equal true
    end

    # 確認目前 DB 有歌但還沒有 lyric
    _(songs_repo.find_by_id(SONG_ID)).wont_be_nil
    _(songs_repo.find_lyric_in_database(song_id: SONG_ID)).must_be_nil

    # ===== 用 Genius + AddLyric：第一次呼叫，會去抓遠端並寫進 DB =====
    first_lyric_in_db = nil

    VCR.use_cassette(
      'genius_api',
      record: :new_episodes,
      match_requests_on: %i[method uri headers]
    ) do
      # 第一次：沒有 local lyric -> fetch_remote_lyric
      first_result = LingoBeats::Service::AddLyric.new.call(song_id: SONG_ID)
      _(first_result.success?).must_equal true

      first_api = first_result.value!
      _(first_api.status).must_equal :ok

      first_lyric = first_api.message
      _(first_lyric).wont_be_nil
      _(first_lyric.respond_to?(:text)).must_equal true
      _(first_lyric.text.to_s.strip.empty?).must_equal false

      # 第一次：DB 有 lyric
      first_lyric_in_db = songs_repo.find_lyric_in_database(song_id: SONG_ID)
      _(first_lyric_in_db).wont_be_nil
      _(first_lyric_in_db.text.to_s.strip.empty?).must_equal false

      # 第二次：有 local lyric，直接用 DB 的
      second_result = LingoBeats::Service::AddLyric.new.call(song_id: SONG_ID)
      _(second_result.success?).must_equal true

      second_api = second_result.value!
      _(second_api.status).must_equal :ok

      second_lyric = second_api.message
      _(second_lyric).wont_be_nil
      _(second_lyric.respond_to?(:text)).must_equal true
      _(second_lyric.text.to_s.strip.empty?).must_equal false

      # DB lyric 沒被改變
      second_lyric_in_db = songs_repo.find_lyric_in_database(song_id: SONG_ID)
      _(second_lyric_in_db).wont_be_nil
      _(second_lyric_in_db.text).must_equal first_lyric_in_db.text

      # 第二次回傳 = DB lyric
      _(second_lyric.text).must_equal second_lyric_in_db.text
    end
  end

  it 'SAD: returns failure when AddSong fails (song not found)' do
    # 先把原本的 AddSong 存起來
    original_add_song = LingoBeats::Service.const_get(:AddSong)

    # 做一個假的 AddSong：永遠回 Failure(ApiResult)
    fake_add_song = Class.new do
      def initialize(*); end

      def call(_song_id:)
        api = LingoBeats::Response::ApiResult.new(
          status: :not_found,
          message: 'Cannot find the specified song'
        )

        Dry::Monads::Result::Failure.new(api)
      end
    end

    begin
      # 把 Service::AddSong 暫時換成 fake 版
      LingoBeats::Service.send(:remove_const, :AddSong)
      LingoBeats::Service.const_set(:AddSong, fake_add_song)

      service = LingoBeats::Service::AddLyric.new
      result  = service.call(song_id: 'non-existent-id-123')

      _(result.failure?).must_equal true

      api = result.failure
      _(api.status).must_equal :not_found
      _(api.message).must_equal 'Cannot find the specified song'
    ensure
      # 把真的 AddSong 放回去
      LingoBeats::Service.send(:remove_const, :AddSong)
      LingoBeats::Service.const_set(:AddSong, original_add_song)
    end
  end
end
