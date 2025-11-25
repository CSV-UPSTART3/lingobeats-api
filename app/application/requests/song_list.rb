# frozen_string_literal: true

require 'base64'
require 'dry/monads'
require 'json'

module LingoBeats
  module Request
    # Song list request parser
    class SongList
      include Dry::Monads::Result::Mixin

      CATEGORY = %w[singer song_name].freeze
      PARAMS_ERROR = 'Invalid query parameters'

      def initialize(params)
        @params = params
      end

      def call
        Success(category: category.value!, query: query.value!)
      rescue StandardError => error
        App.logger.error("Parameter validation error: #{error.message}")
        Failure(Response::ApiResult.new(status: :bad_request, message: PARAMS_ERROR))
      end

      def category
        category = @params['category'].to_s.strip
        raise 'Category parameter is missing.' if category.empty?
        raise "Invalid category: #{category}" unless CATEGORY.include?(category)

        Success(category)
      end

      def query
        query = @params['query'].to_s.strip
        raise 'Query parameter is missing.' if query.empty?

        Success(query)
      end
    end
  end
end
