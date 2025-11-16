# frozen_string_literal: true

require 'dry-validation'

module LingoBeats
  module Forms
    # Form validation for lyric search
    class NewLyric < Dry::Validation::Contract
      MSG_EMPTY_SONG_ID = 'song id should not be empty'

      params do
        required(:id).filled(:string)
        required(:name).filled(:string)
        required(:singer).filled(:string)
      end

      # check if id is not empty
      rule(:id) do
        key.failure(MSG_EMPTY_SONG_ID) if value.to_s.strip.empty?
      end
    end
  end
end
