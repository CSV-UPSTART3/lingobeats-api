# frozen_string_literal: true

require_relative '../../../helpers/spec_helper'
#require_relative '../../../helpers/vcr_helper'
require_relative '../../../helpers/database_helper'

describe LingoBeats::Service::AddVocabularies do
    # 用假的先檢查到底是 service 邏輯有問題，還是外部服務的問題
    FakeSong = Class.new do
        attr_reader :id, :difficulties, :evaluate_called

        def initialize(id:, difficulties: nil)
            @id = id
            @difficulties = difficulties
            @evaluate_called = false
        end

        def evaluate_words
            @evaluate_called = true
            @difficulties
        end
    end

    FakeVocab = Struct.new(:id, :name)

    # 假 repo
    class FakeVocabsRepo
        attr_reader :for_song_called_with,
                    :find_by_names_called_with,
                    :create_many_called_with,
                    :link_songs_called_with

        def initialize(existing_for_song: [], existing_vocabs: [])
            @existing_for_song = existing_for_song
            @existing_vocabs   = existing_vocabs
        end

        def for_song(song_id)
            @for_song_called_with = song_id
            @existing_for_song
        end

        def find_by_names(names)
            @find_by_names_called_with = names
            @existing_vocabs
        end

        def create_many(entities)
            @create_many_called_with = entities
            # 假 id
            entities.each_with_index.map { |ent, idx| FakeVocab.new(idx + 1, ent.name) }
        end

        def link_songs(song_id, vocab_ids)
            @link_songs_called_with = [song_id, vocab_ids]
        end
    end

  describe 'when vocabs already exist for song' do
    it 'skips processing and returns ok' do
        song    = FakeSong.new(id: 'song-123')
        repo    = FakeVocabsRepo.new(existing_for_song: [Object.new])
        service = LingoBeats::Service::AddVocabularies.new(vocabs_repo: repo)

        result = service.call(song)

        _(result.success?).must_equal true
        api_result = result.value!

        _(api_result.status).must_equal :ok
        _(api_result.message).must_be_same_as song  # or must_equal,都可以

        # 確認真的有 skip
        _(repo.for_song_called_with).must_equal 'song-123'
        _(repo.find_by_names_called_with).must_be_nil
        _(repo.create_many_called_with).must_be_nil
        _(repo.link_songs_called_with).must_be_nil

        # evaluate_words 不該被叫
        _(song.evaluate_called).must_equal false
    end
  end

    describe 'when song has no vocabs yet' do
        it 'evaluates words, creates/link vocabs and returns created' do
            difficulties = { 'apple' => 'A1', 'banana' => 'A2' }

            song = FakeSong.new(id: 'song-123', difficulties: difficulties)
            repo = FakeVocabsRepo.new(existing_for_song: [], existing_vocabs: [])

            fake_entities = [
                FakeVocab.new('apple'),
                FakeVocab.new('banana')
            ]

            LingoBeats::Vocabularies::VocabularyBuilder.stub(
                :build_from_difficulties,
                fake_entities
            ) do
                service = LingoBeats::Service::AddVocabularies.new(vocabs_repo: repo)
                result  = service.call(song)

                _(result.success?).must_equal true
                api_result = result.value!

                _(api_result.status).must_equal :created
                _(api_result.message).must_be_same_as song

                # flow 檢查
                _(repo.for_song_called_with).must_equal 'song-123'
                _(song.evaluate_called).must_equal true
                _(repo.find_by_names_called_with).must_equal difficulties.keys
                _(repo.create_many_called_with).must_equal fake_entities

                song_id, vocab_ids = repo.link_songs_called_with
                _(song_id).must_equal 'song-123'
                _(vocab_ids).wont_be_empty
            end
        end
    end
end