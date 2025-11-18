# frozen_string_literal: true

require 'dry-validation'

module LingoBeats
  module Forms
    # Form validation for search records
    class DeleteSearch < Dry::Validation::Contract
      MSG_EMPTY_CATEGORY = 'category should not be empty'
      MSG_EMPTY_QUERY = 'query should not be empty'

      params do
        required(:category).filled(:string)
        required(:query).filled(:string)
      end

      # check if category is not empty
      rule(:category) do
        key.failure(MSG_EMPTY_CATEGORY) if value.to_s.strip.empty?
      end

      # check if query is not empty
      rule(:query) do
        key.failure(MSG_EMPTY_QUERY) if value.to_s.strip.empty?
      end
    end
  end
end
