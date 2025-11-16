# frozen_string_literal: true

module LingoBeats
  module Value
    # Tokenizer for song lyrics
    class Tokenizer
      def initialize(cleaned_text)
        @cleaned_text = cleaned_text
      end

      def call
        return [] if TokenizerHelpers.blank?(@cleaned_text)

        TokenizerHelpers.extract_words(@cleaned_text)
                        .reject { |word| TokenizerHelpers.stopwords.include?(word) }
                        .uniq
      end

      # Helper methods for tokenization
      module TokenizerHelpers
        module_function

        def blank?(text)
          text.to_s.strip.empty?
        end

        def extract_words(text)
          text.downcase.scan(/[a-z']+/)
        end

        def stopwords
          common = %w[a an the in on at for to of is am are was were do did have has had and or but]
          lyric  = %w[verse chorus bridge outro pre-chorus post-chorus
                      oh ah hah yeah woah ooh la na uh yo hey ha haaa]
          (common + lyric).to_set(&:downcase)
        end
      end
    end
  end
end
