# frozen_string_literal: true

module LingoBeats
  module Service
    # Service: store vocabularies (name + level) for a song
    class VocabularyStorageService
      def initialize(vocab_repo:)
        @vocab_repo = vocab_repo
      end

      # 主流程：斷詞 & 評級 → 存 vocab → 建 song-vocab 關聯
      def store_from_song(song)
        # 如果這首歌已經建立過 vocab 關聯 → 不重跑 evaluate_words
        existing = @vocab_repo.for_song(song.id)
        return [] if existing.any?

        difficulties = song.evaluate_words # => { "ghost" => "A", ... }
        return [] if difficulties.empty?

        stored = []

        difficulties.each do |word, level|
          vocab = Entity::Vocabulary.new(
            id: nil,
            name: word,
            level: level,
            material: nil   # ⚠ 現階段不做 Gemini，因此保持 nil
          )

          existing = @vocab_repo.find_by_name(word)

          if existing
            @vocab_repo.link_song(song.id, existing.id)
            next
          end

          saved = @vocab_repo.create(vocab)
          @vocab_repo.link_song(song.id, saved.id)

          stored << saved
        end

        stored
      end
    end
  end
end
