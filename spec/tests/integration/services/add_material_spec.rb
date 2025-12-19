# frozen_string_literal: true

require_relative '../../../helpers/spec_helper'
require_relative '../../../helpers/vcr_helper'
require_relative '../../../helpers/yaml_helper'
require_relative '../../../helpers/database_helper'
require 'json'

describe 'AddMaterial Service Integration Test' do
  before do
    DatabaseHelper.wipe_database

    @song_repo = LingoBeats::Repository::For.klass(LingoBeats::Entity::Song)
    @vocab_repo = LingoBeats::Repository::For.klass(LingoBeats::Entity::Vocabulary)

    @song = @song_repo.create(
      LingoBeats::Entity::Song.new(
        id: 'test-song-001',
        name: 'Test Song',
        uri: 'spotify:track:testsong001',
        external_url: 'https://open.spotify.com/track/testsong001',
        album_id: 'test-album-001',
        album_name: 'Test Album',
        album_url: 'https://open.spotify.com/album/testalbum001',
        album_image_url: 'https://i.scdn.co/image/testalbumimage001',
        lyric: nil,
        singers: []
      )
    )

    @vocab = @vocab_repo.create(
      LingoBeats::Entity::Vocabulary.new(
        id: 1,
        name: 'ghost',
        original_word: 'ghost',
        level: 'A1',
        material: '{"head_zh":"test","meanings":[{"pos":"test","definition_en":"test","definition_zh":"test",
        "examples":[{"sentence_en":"test","explanation_zh":"test"},
        {"sentence_en":"test","explanation_zh":"test"}]}],
        "related_forms":[{"form":"test","pos":"test"}]}'
      )
    )
    
    @vocab_repo.link_song(@song.id, @vocab.id)

    
  end

  it 'HAPPY: returns :ok and existing material when all vocabs already have material' do
    service = LingoBeats::Service::AddMaterial.new(
      songs_repo: @song_repo,
      vocabs_repo: @vocab_repo,
      mapper: Object.new,
      material_job_queue: Object.new
    )

    expected_contents = @vocab_repo.vocabs_content(@song.id)

    result = service.call(song_id: @song.id)

    assert result.success?
    api = result.value!

    assert_equal :ok, api.status

    assert_kind_of LingoBeats::Response::Material, api.message
    assert_equal @song.name, api.message.song
    assert_equal expected_contents, api.message.contents
  end

  # TODO: 
  # HAPPY: 有vocab但沒有material的情況


  it 'SAD: failswith VOCAB_NOT_EXISTS when song has no vocabularies' do

    @song_repo.create(
      LingoBeats::Entity::Song.new(
        id: 'test-song-novocab',
        name: 'Test Song',
        uri: 'spotify:track:testsongnovocab',
        external_url: 'https://open.spotify.com/track/testsongnovocab',
        album_id: 'test-album-novocab',
        album_name: 'Test Album',
        album_url: 'https://open.spotify.com/album/testalbumnovocab',
        album_image_url: 'https://i.scdn.co/image/testalbumimagenovocab',
        lyric: nil,
        singers: []
      )
    )

    service = LingoBeats::Service::AddMaterial.new(
      songs_repo: @song_repo,
      vocabs_repo: @vocab_repo,
      mapper: Object.new,
      material_job_queue: Object.new
    )

    result = service.call(song_id: 'test-song-novocab')

    assert result.failure?
    api = result.failure
    assert_equal :internal_error, api.status
    assert_equal LingoBeats::Service::AddMaterial::VOCAB_NOT_EXISTS, api.message
  end

  it 'SAD: fails with SONG_NOT_EXISTS when song not found' do
    service = LingoBeats::Service::AddMaterial.new(
      songs_repo: @song_repo,
      vocabs_repo: @vocab_repo,
      mapper: Object.new,
      material_job_queue: Object.new
    )

    result = service.call(song_id: 'test-song-notexist')

    assert result.failure?
    api = result.failure
    assert_equal :internal_error, api.status
    assert_equal LingoBeats::Service::AddMaterial::SONG_NOT_EXISTS, api.message
  end
end
