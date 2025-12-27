# frozen_string_literal: true

module LingoBeats
  module Songs
    module Services
      # Builds a lookup map for lyric word positions to maintain order
      class LyricWordOrder
        def initialize(song, tokenizer: Tokenizer)
          @tokenizer = tokenizer
          @positions, @token_count = tokenize_lyric(song&.lyric&.text)
        end

        def size
          @token_count
        end

        def position_for(word, fallback)
          normalized = @tokenizer.normalize(word)
          @positions.fetch(normalized, fallback)
        end

        private

        def tokenize_lyric(text)
          tokens = @tokenizer.tokenize(text)
          [build_positions(tokens), tokens.length]
        end

        def build_positions(tokens)
          tokens.each_with_index.with_object({}) do |(token, index), memo|
            normalized = @tokenizer.normalize(token)
            memo[normalized] ||= index
          end
        end

        # Responsible for tokenizing lyric text and normalizing words
        module Tokenizer
          module_function

          def tokenize(text)
            normalize_text(text).scan(/[a-z']+/)
          end

          def normalize(word)
            word.to_s.downcase
          end

          def normalize_text(text)
            text.to_s.downcase
          end
        end
      end
    end
  end
end
