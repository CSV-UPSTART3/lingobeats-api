# frozen_string_literal: true

require_relative 'helpers/spec_helper'
require_relative 'helpers/vcr_helper'
require_relative 'helpers/yaml_helper'
require 'json'
require 'ostruct'

describe 'Tests Gemini API → Vocabulary pipeline' do
  before do
    VcrHelper.setup_vcr
    VcrHelper.configure_vcr_for_gemini
  end

  after do
    VcrHelper.eject_vcr
  end

  # 簡單的 in-memory Vocabulary repo(for spec)
  # 接上 db 以後可以改掉
  class InMemoryVocabularyRepo
    def initialize(vocabs)
      @store = {}
      vocabs.each do |v|
        (@store[v.song_id] ||= []) << v
      end
    end

    def for_song(song_id)
      Array(@store[song_id])
    end

    def update(vocab)
      list = (@store[vocab.song_id] ||= [])
      idx  = list.index { |v| v.name == vocab.name }
      idx ? list[idx] = vocab : list << vocab
    end

    def all
      @store.values.flatten
    end
  end

  it 'HAPPY: generates vocabulary materials for a song via service' do
    gemini_key = defined?(GEMINI_API_KEY) ? GEMINI_API_KEY : ENV.fetch('GEMINI_API_KEY', nil)
    skip 'GEMINI_API_KEY not set; skipping integration spec' unless gemini_key

    # --- 準備一首假的歌 + CEFR 結果 ---
    level   = 'A2'
    song_id = 'spotify:track:test-123'
    song    = OpenStruct.new(id: song_id, title: 'Test Song')

    # 簡化版 CEFR 結果（避免一次丟太多 token）
    cefr_result = {
      'ghost' => level,
      'alone' => level,
      'queen' => level
    }

    # 把 vocabs（material 為空）建成 domain entity
    initial_vocabs = cefr_result.map do |word, lvl|
      LingoBeats::Entity::Vocabulary.new(
        song_id: song_id,
        name: word,
        level: lvl,
        material: {} # 先留空，等等由 service 填入
      )
    end

    vocab_repo = InMemoryVocabularyRepo.new(initial_vocabs)

    # 建立 Gemini mapper
    mapper = LingoBeats::Gemini::VocabularyMapper.new(access_token: gemini_key)

    # 呼叫 service
    service = LingoBeats::Vocabularies::Services::GenerateMaterialsForSong.new(
      vocabulary_repo: vocab_repo,
      mapper: mapper
    )

    updated_vocabs = service.call(song)

    # --- 驗證：至少有一些 vocab 被填上 material ---
    _(updated_vocabs).wont_be_empty
    updated_vocabs.each do |vocab|
      _(vocab).must_be_kind_of LingoBeats::Entity::Vocabulary
      _(vocab.song_id).must_equal song_id
      _(vocab.level).must_equal level

      _(vocab.material).wont_be_nil
      _(vocab.material).must_be_kind_of Hash

      # material hash must = schema
      _(vocab.material).must_include :word
      _(vocab.material).must_include :entries
      _(vocab.material[:entries]).must_be_kind_of Array
    end
  end

  it 'SAD: returns empty array when model output is empty/invalid' do
    bad_payload = { 'candidates' => [{ 'content' => { 'parts' => [] } }] }

    result = LingoBeats::Gemini::VocabularyMapper::MaterialParser.parse_batch(bad_payload)

    _(result).must_be_kind_of Array
    _(result).must_be_empty
  end
end
