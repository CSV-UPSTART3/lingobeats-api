# frozen_string_literal: true

require_relative '../../../helpers/spec_helper'
require_relative '../../../helpers/vcr_helper'
require_relative '../../../helpers/yaml_helper'
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
    def initialize(song, vocabs)
      # { song_id => [vocab1, vocab2, ...] }
      @store = { song.id => vocabs }
    end

    # 給 AddMaterial 用來抓 vocabs
    def for_song(song_id)
      Array(@store[song_id])
    end

    # 給 AddMaterial 用來更新 material
    def update_material(id, material_str)
      @store.each_value do |list|
        idx = list.index { |v| v.id == id }
        next unless idx

        old = list[idx]
        updated = LingoBeats::Entity::Vocabulary.new(
          old.to_attr_hash.merge(material: material_str)
        )
        list[idx] = updated
        return updated
      end
      nil
    end

    # 方便最後檢查 vocabs 被塞了什麼
    def vocabs_content(song_id)
      Array(@store[song_id]).map do |v|
        {
          id:       v.id,
          name:     v.name,
          level:    v.level,
          material: v.material
        }
      end
    end

    def all
      @store.values.flatten
    end
  end

  class InMemorySongRepo
    def initialize(songs = [])
      @songs = {}
      songs.each { |song| @songs[song.id] = song }
    end

    def find_by_id(id)
      @songs[id]
    end

    def add(song)
      @songs[song.id] = song
    end
  end


  it 'HAPPY: generates vocabulary materials for a song via service (using fake mapper)' do
    # 準備一首假的歌
    SongStub = Struct.new(:id, :name)
    song = SongStub.new('song-123', 'Golden')

    # 簡化版 CEFR 結果：假設只有兩個單字
    cefr_result = {
      'ghost' => 'A2',
      'alone' => 'A2'
    }

    # 建 vocabs（material 先是 nil）
    initial_vocabs = cefr_result.map.with_index do |(word, level), idx|
      LingoBeats::Entity::Vocabulary.new(
        id: idx + 1,
        name: word,
        level: level,
        material: nil
      )
    end

    vocab_repo = InMemoryVocabularyRepo.new(song, initial_vocabs)
    song_repo  = InMemorySongRepo.new([song])

    # fake 的 Gemini 輸出：長得像 mapper 真的會吐出來的格式
    fake_materials = initial_vocabs.map do |v|
      {
        word: v.name,
        entries: [
          { meaning: "fake meaning for #{v.name}",
            example: "fake example for #{v.name}" }
        ]
      }
    end

    # fake mapper：只要有人給我 String prompt，我就回 fake_materials
    mapper = Minitest::Mock.new
    mapper.expect :generate_and_parse, fake_materials, [String]

    service = LingoBeats::Service::AddMaterial.new(
      vocabs_repo: vocab_repo,
      songs_repo:  song_repo,
      mapper:      mapper
    )

    # act
    result = service.call(song_id: song.id)

    # assert: 先確定是成功 Result
    _(result).must_be_kind_of Dry::Monads::Result::Success
    api_result = result.value!

    _(api_result).must_be_kind_of LingoBeats::Response::ApiResult
    _(api_result.status).must_equal :created

    material_response = api_result.message
    _(material_response).must_be_kind_of LingoBeats::Response::Material

    contents = material_response.contents
    _(contents.size).must_equal initial_vocabs.size

    # 再檢查 repo 裡的 vocabs 真的被塞了 material，而且 schema 看起來對
    stored = vocab_repo.vocabs_content(song.id)
    _(stored.size).must_equal initial_vocabs.size

    stored.each do |v|
      _(v[:material]).wont_be_nil
      json = JSON.parse(v[:material], symbolize_names: true)

      _(json).must_be_kind_of Hash
      _(json).must_include :word
      _(json).must_include :entries
      _(json[:entries]).must_be_kind_of Array
    end

    mapper.verify
  end

  it 'SAD: returns empty array when model output is empty/invalid' do
    bad_payload = { 'candidates' => [{ 'content' => { 'parts' => [] } }] }

    result = LingoBeats::Gemini::VocabularyMapper::MaterialParser.parse_batch(bad_payload)

    _(result).must_be_kind_of Array
    _(result).must_be_empty
  end
end
