# frozen_string_literal: true

require_relative 'song'

module Views
  # View for a a list of song entities
  class SongsList
    def initialize(songs)
      @songs = songs.map do |song|
        song.is_a?(Song) ? song : Song.new(song)
      end
    end

    def each(&show)
      @songs.each do |song|
        show.call song
      end
    end

    def any?
      @songs.any?
    end
  end
end
