# frozen_string_literal: true

module Views
  # View for a single lyric entity
  class Lyric
    def initialize(lyric)
      @lyric = lyric
    end

    def entity
      @lyric
    end

    def text
      @lyric&.text
    end
  end
end
