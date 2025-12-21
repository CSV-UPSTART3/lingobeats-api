# frozen_string_literal: true

require 'fileutils'
require 'json'
require 'rack/test'

require_relative '../../helpers/spec_helper'
require_relative '../../helpers/database_helper'
require_relative '../../helpers/vcr_helper'

CASSETTE_OPTS = { record: :new_episodes, match_requests_on: %i[method uri] }.freeze

# Ensure Authorization header is normalized so replays can match
VCR.configure do |config|
  config.before_record do |interaction|
    auth = interaction.request.headers['Authorization']&.first
    if auth&.start_with?('Bearer ')
      interaction.request.headers['Authorization'] = ['Bearer <SPOTIFY_ACCESS_TOKEN>']
    end
  end
end

describe 'LingoBeats API acceptance reference spec' do
  include Rack::Test::Methods

  def app
    LingoBeats::App
  end

  before do
    ensure_test_database!
    DatabaseHelper.wipe_database
  end

  after do
    DatabaseHelper.wipe_database
  end

  describe 'GET /' do
    it 'exposes a simple health endpoint' do
      get '/'

      _(last_response.status).must_equal 200
      body = JSON.parse(last_response.body)
      _(body['status']).must_equal 'ok'
      _(body['message']).must_include 'API is working'
    end
  end

  describe 'GET /api/v1/songs' do
    it 'lists popular songs via Spotify data' do
      use_spotify_cassette('songs/index_popular') do
        get '/api/v1/songs'
      end

      _(last_response.status).must_equal 200
      body = JSON.parse(last_response.body)

      _(body).must_include 'songs'
      _(body['songs']).must_be_kind_of Array
    end

    it 'filters songs when query params provided' do
      use_spotify_cassette('songs/filter_by_name') do
        get '/api/v1/songs', { category: 'song_name', query: 'Golden' }
      end

      _(last_response.status).must_equal 200
      body = JSON.parse(last_response.body)

      _(body).must_include 'songs'
      _(body['songs']).must_be_kind_of Array
    end
  end

  describe 'GET /api/v1/songs/:id' do
    it 'returns a previously seeded song without re-hitting Spotify' do
      seed_song!

      get "/api/v1/songs/#{SONG_ID}"

      _(last_response.status).must_equal 200
      song = JSON.parse(last_response.body)
      _(song['id']).must_equal SONG_ID
      _(song['name']).wont_be_nil
      _(song['album_name']).wont_be_nil
    end

    it 'responds with error for unknown ids' do
      get '/api/v1/songs/non-existent-song'

      _(last_response.status).must_equal 500
    end
  end

  describe 'GET /api/v1/songs/:id/lyrics' do
    it 'serves cached lyrics once Genius result is stored' do
      seed_lyric!

      get "/api/v1/songs/#{SONG_ID}/lyrics"

      _(last_response.status).must_equal 200
      body = JSON.parse(last_response.body)
      _(body['text']).wont_be_nil
    end

    it 'returns error for unknown songs' do
      get '/api/v1/songs/not-found-id/lyrics'

      _(last_response.status).must_equal 500
    end
  end

  describe 'GET /api/v1/songs/:id/level' do
    it 'returns distribution and average level for seeded song' do
      seed_lyric! # adds song + lyric + vocabularies

      get "/api/v1/songs/#{SONG_ID}/level"

      _(last_response.status).must_equal 200
      body = JSON.parse(last_response.body)
      _(body).must_include 'distribution'
      _(body).must_include 'level'
    end

    it 'returns 404 when song not found' do
      get '/api/v1/songs/unknown-id/level'

      _(last_response.status).must_equal 404
    end
  end

  describe 'GET /api/v1/songs/:id/material' do
    it 'returns materials when vocabularies have content' do
      seed_lyric!
      assign_fake_materials!

      get "/api/v1/songs/#{SONG_ID}/material"

      _(last_response.status).must_equal 200
      body = JSON.parse(last_response.body)
      _(body).must_include 'song'
      _(body).must_include 'contents'
      _(body['contents']).wont_be_empty
      first = body['contents'].first
      _(first).must_include 'word'
      _(first).must_include 'level'
      _(first).must_include 'id'
    end

    it 'returns not_found when materials are not generated yet' do
      seed_lyric! # ensures vocabularies exist in test.db

      get "/api/v1/songs/#{SONG_ID}/material"

      _(last_response.status).must_equal 404
      body = JSON.parse(last_response.body)
      _(body['message']).must_match(/Material not generated/i)
    end

    it 'returns 404 when song id invalid' do
      get '/api/v1/songs/non-existent-id/material'

      _(last_response.status).must_equal 404
    end
  end

  describe 'POST /api/v1/songs/:id/material' do
    it 'serves materials immediately when everything already generated' do
      seed_lyric!
      assign_fake_materials!

      post "/api/v1/songs/#{SONG_ID}/material"

      _(last_response.status).must_equal 302
      follow_redirect!

      _(last_response.status).must_equal 200
      body = JSON.parse(last_response.body)
      _(body).must_include 'song'
      _(body['contents']).wont_be_empty
    end

    it 'queues material generation when vocabularies incomplete' do
      seed_lyric!

      with_fake_add_material do |fake_service|
        post "/api/v1/songs/#{SONG_ID}/material"

        _(last_response.status).must_equal 201
        body = JSON.parse(last_response.body)
        _(body['status']).must_equal 'created'
        _(body['message']).must_include 'Golden'
        _(fake_service.called_with).must_equal SONG_ID
      end
    end
  end

  def seed_song!(song_id = SONG_ID)
    use_spotify_cassette('songs/seed_add_song') do
      LingoBeats::Service::AddSong.new.call(song_id:)
    end
  end

  def seed_lyric!(song_id = SONG_ID)
    seed_song!(song_id)
    use_genius_cassette('lyrics/seed_add_lyric') do
      LingoBeats::Service::AddLyric.new.call(song_id:)
    end
  end

  def assign_fake_materials!(song_id = SONG_ID)
    repo = LingoBeats::Repository::For.klass(LingoBeats::Entity::Vocabulary)
    vocabs = repo.for_song(song_id)
    _(vocabs).wont_be_empty

    vocabs.each do |vocab|
      repo.update_material(vocab.id, fake_material_json(vocab.name))
    end
  end

  def fake_material_json(word)
    {
      word:,
      entries: [
        { meaning: "fake meaning for #{word}", example: "fake example for #{word}" }
      ]
    }.to_json
  end

  def with_fake_add_material
    fake_service = Class.new do
      class << self
        attr_accessor :called_with
      end

      def initialize(*); end

      def call(song_id:, request_id: nil)
        self.class.called_with = song_id
        material = LingoBeats::Response::Material.new(
          song: 'Golden',
          contents: [
            { word: 'take', entries: [{ meaning: 'fake meaning', example: 'fake example' }] }
          ]
        )

        fake_result = LingoBeats::Response::ApiResult.new(status: :created, message: material)
        Dry::Monads::Result::Success.new(fake_result)
      end
    end

    original = LingoBeats::Service.const_get(:AddMaterial)
    LingoBeats::Service.send(:remove_const, :AddMaterial)
    LingoBeats::Service.const_set(:AddMaterial, fake_service)

    yield(fake_service)
  ensure
    LingoBeats::Service.send(:remove_const, :AddMaterial)
    LingoBeats::Service.const_set(:AddMaterial, original)
  end

  def ensure_test_database!
    db_file = LingoBeats::App.config.DB_FILENAME
    _(db_file).must_match(/test\.db\z/)
  end

  def use_spotify_cassette(name, &block)
    use_cassette('spotify', name, &block)
  end

  def use_genius_cassette(name, &block)
    use_cassette('genius', name, &block)
  end

  def use_cassette(provider, name, &block)
    ensure_cassette_folder(provider)
    VCR.use_cassette("#{provider}/#{name}", **CASSETTE_OPTS) do
      block.call
    end
  end

  def ensure_cassette_folder(provider)
    FileUtils.mkdir_p(File.join(VcrHelper::CASSETTES_FOLDER, provider))
  end
end
