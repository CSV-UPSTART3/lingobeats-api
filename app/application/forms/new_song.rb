# frozen_string_literal: true

require 'dry-validation'

module LingoBeats
  module Forms
    # Form validation for song search
    class NewSong < Dry::Validation::Contract
      CATEGORY = %w[singer song_name].freeze
      MSG_INVALID_CATEGORY = 'is not a valid category'
      MSG_EMPTY_QUERY = 'query should not be empty'

      params do
        required(:category).filled(:string)
        required(:query).filled(:string)
      end

      # check if category is valid
      rule(:category) do
        key.failure(MSG_INVALID_CATEGORY) unless CATEGORY.include?(value)
      end

      # check if query is not empty
      rule(:query) do
        key.failure(MSG_EMPTY_QUERY) if value.to_s.strip.empty?
      end
    end
  end
end
