# frozen_string_literal: true

require_relative '../../../helpers/spec_helper'
#require_relative '../../../helpers/vcr_helper'
require_relative '../../../helpers/database_helper'

describe 'AddVocabularies Service Integration Test' do
    before do
        DatabaseHelper.wipe_database

        @song_repo = LingoBeats::Repository::For.klass(LingoBeats::Entity::Song)
        @vocabs_repo = LingoBeats::Repository::For.klass(LingoBeats::Entity::Vocabulary)

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
    end

    it 'HAPPY: returns :ok and skips processing when song already has vocabularies' do

        vocab = @vocabs_repo.create(
            LingoBeats::Entity::Vocabulary.new(
                id: 1,
                name: 'ghost',
                original_word: 'ghost',
                level: 'A1',
                material: nil
            )
        )
        
        @vocabs_repo.link_song(@song.id, vocab.id)

        service = LingoBeats::Service::AddVocabularies.new(
            vocabs_repo: @vocabs_repo
        )

        before_count = @vocabs_repo.for_song(@song.id).count

        result = service.call(@song)

        assert result.success?
        api = result.value!

        assert_equal :ok, api.status
        assert_equal @song, api.message

        after_count = @vocabs_repo.for_song(@song.id).count
        assert_equal before_count, after_count
    end

    it 'HAPPY: creates vocabularies and return :created when song has no vocabularies yet' do
        service = LingoBeats::Service::AddVocabularies.new(
                vocabs_repo: @vocabs_repo
        )

        difficulties = [
            {'origin_word' => 'ghost', 'lemma' => 'ghost', 'level' => 'A'}
        ]

        @song.define_singleton_method(:evaluate_words) do
          difficulties
        end

        before_count = @vocabs_repo.for_song(@song.id).count
        result = service.call(@song)
        after_count = @vocabs_repo.for_song(@song.id).count

        assert result.success?
        api = result.value!

        assert_equal :created, api.status
        assert_equal @song, api.message

        assert_operator after_count, :>, before_count
    end
end