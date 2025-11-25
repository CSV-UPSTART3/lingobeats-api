# frozen_string_literal: true

# python
require 'open3'

require 'yaml'
require 'fileutils'
require_relative '../spec/helpers/yaml_helper'
require_relative '../app/infrastructure/spotify/gateways/spotify_api'
require_relative '../app/infrastructure/genius/gateways/genius_api'
require_relative '../app/infrastructure/gemini/gateways/gemini_api'
require_relative '../app/infrastructure/spotify/mappers/song_mapper'
require_relative '../app/infrastructure/genius/mappers/lyric_mapper'
require_relative '../app/infrastructure/gemini/mappers/vocabulary_mapper'
require_relative '../app/domain/vocabularies/entities/vocabulary'
require_relative '../app/domain/vocabularies/services/generate_materials_for_song'

dir = 'spec/fixtures'
FileUtils.mkdir_p(dir)

# --- call spotify api ---
ROOT = File.expand_path('../', __dir__)
CONFIG = YAML.safe_load_file(File.join(ROOT, 'config/secrets.yml'))

client = LingoBeats::Spotify::SongMapper.new(CONFIG['development']['SPOTIFY_CLIENT_ID'],
                                             CONFIG['development']['SPOTIFY_CLIENT_SECRET'])
spotify_result_by_singer = client.search_songs_by_singer('Ed Sheeran')
spotify_result_by_song_name = client.search_songs_by_song_name('Golden')
billboard_result = client.display_popular_songs
song_info = client.fetch_song_info_by_id('7qiZfU4dY1lWllzX7mPBI3') # Shape of You

YamlHelper.export_yaml(
  spotify_result_by_singer,
  file_path: File.join(dir, 'spotify_result_by_singer.yml')
)

YamlHelper.export_yaml(
  spotify_result_by_song_name,
  file_path: File.join(dir, 'spotify_result_by_song_name.yml')
)

YamlHelper.export_yaml(
  billboard_result,
  file_path: File.join(dir, 'billboard_result.yml')
)

YamlHelper.export_yaml(
  song_info,
  file_path: File.join(dir, 'song_info.yml')
)

File.write(File.join(dir, 'spotify_result_by_singer.yml'), spotify_result_by_singer.to_yaml)
File.write(File.join(dir, 'spotify_result_by_song_name_test.yml'), combined_data.to_yaml)
File.write(File.join(dir, 'billboard_result.yml'), billboard_result.to_yaml)

# --- call genius api ---
genius_client = LingoBeats::Genius::LyricMapper.new(CONFIG['development']['GENIUS_CLIENT_ACCESS_TOKEN'])

# Clean and extract lyrics text
lyrics = genius_client.lyrics_for(song_name: 'Golden', artist_name: 'HUNTR/X')
lyrics_text = lyrics&.text
File.write(File.join(dir, 'lyrics_output.txt'), lyrics_text)
puts "歌詞已輸出到 spec/lyrics_output.txt"

# 呼叫 Python 腳本
# input_path  = File.join(dir, 'lyrics_output.txt')
# input_text  = File.read(input_path).strip
# input_text = lyrics_text
python_script = File.join('app/domain/songs/services', 'cefrpy_service.py')
cmd = ['python3', python_script, lyrics.clean_words.to_s] # lyrics.clean_words.to_s 會得到字串形式的詞彙 list

stdout, stderr, status = Open3.capture3(*cmd)

unless status.success?
  warn "Python error: #{stderr}"
  exit 1
end

# 處理並寫出結果
result = begin
  JSON.parse(stdout)
rescue StandardError
  stdout
end
output_path = File.join(dir, 'cefr_result.txt')
File.open(output_path, 'w') do |f|
  f.puts JSON.pretty_generate(result)
end

puts "CEFR 分析完成，輸出已寫入 #{output_path}"

# --- call gemini api ---
api_key = CONFIG['development']['GEMINI_API_KEY'] or raise 'GEMINI_API_KEY missing'
result = JSON.parse(File.read(File.join(dir, 'cefr_result.txt')))
# puts result.first(1).to_h

# 1) 先準備一個假 song（之後真正接 controller 就會變成真的 Song）
SongStub = Struct.new(:id, :name)
song = SongStub.new('0bHs3ly4Bv5BlzE3KrePfX', 'Golden')
class InMemoryVocabularyRepo
  def initialize(song, vocabs)
    @store = {}
    vocabs.each do |v|
      (@store[song.id] ||= []) << v
    end
    # puts @store
  end

  # 給 GenerateMaterialsForSong 用的介面
  def for_song(song_id)
    Array(@store[song_id])
  end

  # 更新：用 word 當 key 找到舊的，換成新的
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

  # 方便最後輸出全部看看
  def all
    @store.values.flatten
  end
end

# 2) 用 result 生出 in-memory 的 Vocabulary entities
initial_vocabs = result.map.with_index do |(word, level), idx|
  LingoBeats::Entity::Vocabulary.new(
    id: idx + 1,            # ⭐ 加上假的自增 ID
    name: word,
    level: level,
    material: nil # 一開始先是空的，等等由 service 幫你塞進去
  )
end

vocabulary_repo = InMemoryVocabularyRepo.new(song, initial_vocabs)

# 3) 準備 gateway（打 Gemini 的 client）跟 mapper（解析 payload）
# gateway = gemini_client.gateway
mapper  = LingoBeats::Gemini::VocabularyMapper.new(access_token: api_key)

# 4) service 只拿 repo + mapper，不再拿 gateway
service = LingoBeats::Vocabularies::Services::GenerateMaterialsForSong.new(
  vocabulary_repo: vocabulary_repo,
  mapper: mapper
)

# 5) 像 controller 一樣，對 service 下指令：「幫這首歌生成 vocab materials」
updated_vocabs = service.call(song)

# 6) 把生成結果寫進 .json 檔，方便你打開檢查
output      = updated_vocabs.map(&:to_attr_hash)
output_path = File.join(dir, 'vocabulary_materials_preview.json')

File.write(output_path, JSON.pretty_generate(output))
puts "生成完成 #{output_path}"

# gemini_client = LingoBeats::GeminiClient.new
# learning_materials = gemini_client.build_learning_materials(query)
# File.write(File.join(dir, 'learning_materials.txt'), learning_materials)
# puts "學習材料已輸出到 spec/learning_materials.txt"
