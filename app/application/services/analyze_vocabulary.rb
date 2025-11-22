# frozen_string_literal: true

module LingoBeats
  module Service
    # Service to analyze vocabulary data for songs
    class AnalyzeVocabulary
      def initialize(vocab_repo: Repository::For.klass(Entity::Vocabulary))
        @vocab_repo = vocab_repo
      end

      def distribution_for(song)
        vocabs = @vocab_repo.for_song(song.id)
        vocabs.group_by(&:level).transform_values(&:count)
      end

      def difficulty_distribution(song)
        song.difficulty_distribution
      end

      def average_difficulty(song)
        song.average_difficulty
      end
    end
  end
end
