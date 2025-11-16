# frozen_string_literal: true

module LingoBeats
  module Vocabularies
    module Services
      # 負責：幫「一首歌」底下還沒有 material 的 vocabularies 批次生成 material
      class GenerateMaterialsForSong
        BATCH_SIZE = 10

        def initialize(vocabulary_repo:, mapper:)
          @vocabulary_repo = vocabulary_repo # 存取 Vocabulary 的 repository
          # @gateway         = gateway           # 打 Gemini API 的 client (LingoBeats::Gemini::Api)
          @mapper          = mapper # 解析 Gemini payload 的 mapper (例如 VocabularyMapper)
        end

        # 呼叫方式：service.call(song)
        #
        # 回傳：更新後的 vocab 陣列（已經帶 material）
        def call(song)
          vocabs = load_vocabs_for(song)
          pending = vocabs.select { |v| material_blank?(v) }
          return [] if pending.empty?

          updated = []

          pending.each_slice(BATCH_SIZE) do |batch|
            prompt = build_prompt(batch, song)
            # payload = @mapper.gateway.generate_content(prompt)

            # 假設 mapper.parse_batch(payload) 會回傳：
            # [ {..material_hash_for_word1..}, {..for_word2..}, ... ]
            materials = @mapper.generate_and_parse(prompt)

            batch.zip(materials).each do |vocab, material_hash|
              next if material_hash.nil?

              updated_vocab = build_updated_vocab(vocab, material_hash)
              @vocabulary_repo.update(updated_vocab)
              updated << updated_vocab
            end
          end

          updated
        end

        private

        def load_vocabs_for(song)
          # 這裡依你們實際的 repository 介面調整
          # 比方：
          # @vocabulary_repo.find_by_song_id(song.id)
          @vocabulary_repo.for_song(song.id)
        end

        def material_blank?(vocab)
          vocab.material.nil? || vocab.material.empty?
        end

        # Dry::Struct 是 immutable，所以要 new 一個新的回去
        def build_updated_vocab(vocab, material_hash)
          attrs = vocab.to_attr_hash.merge(material: material_hash)
          LingoBeats::Entity::Vocabulary.new(attrs)
        end

        # 這裡組你的「給 Gemini 的 prompt」
        # 先假設：同一 batch 裡的 vocab level 一樣
        def build_prompt(batch, song)
          words = batch.map(&:name)
          level = batch.first.level

          <<~PROMPT
            You are an English learning assistant for Taiwanese learners.

            TASK:
            For EACH word in the given list, return a detailed vocabulary entry with:
            1. Multiple part-of-speech entries (noun, verb, adjective… as applicable).
            2. A short Traditional Chinese gloss for the word (head_zh).
                - Example: for "ghost", head_zh should be like "鬼魂、幽靈".
            3. For each part-of-speech entry:
                - definition_en: short, simple English explanation (CEFR #{level} level).
                - definition_zh: clear Traditional Chinese explanation, natural and easy to understand.
                - examples: 2–3 everyday example sentences (CEFR #{level}), natural spoken/written English and it's explain in Chinese.
            4. related_forms: common derivatives or different grammatical forms of the word
                (e.g. ghostly, ghosting, staged, wildness), with part-of-speech.

            OUTPUT FORMAT (IMPORTANT):
            Return ONLY valid JSON.
            NO markdown, NO comments, NO explanations outside JSON.

            JSON SCHEMA:
            [
                {
                "word": "string",
                "head_zh": "string",
                "entries": [
                    {
                    "pos": "string",
                    "definition_en": "string",
                    "definition_zh": "string",
                    "examples": ["string", "string"]
                    }
                ],
                "related_forms": [
                    {
                    "form": "string",
                    "pos": "string"
                    }
                ]
                }
            ]

            LEVEL: #{level}
            SONG_TITLE: #{song.title}
            WORD LIST:
            #{words.to_json}

            OUTPUT FORMAT (IMPORTANT):
            Return ONLY valid JSON. No markdown, no comments, no code fences, no ``` blocks.
          PROMPT
        end
      end
    end
  end
end
