# frozen_string_literal: true

require 'dry/monads'

module LingoBeats
  module Request
    # Parses vocabulary ids from query params
    class VocabularyIds
      include Dry::Monads::Result::Mixin

      PARAM_REQUIRED = 'ids parameter is required'
      PARAM_INVALID = 'ids must be integers'

      class MissingIdsError < StandardError; end

      def initialize(params)
        @params = params
      end

      def call
        ids = extract_ids
        raise MissingIdsError if ids.empty?

        Success(ids:)
      rescue MissingIdsError
        Failure(Response::ApiResult.new(status: :cannot_process, message: PARAM_REQUIRED))
      rescue ArgumentError
        Failure(Response::ApiResult.new(status: :cannot_process, message: PARAM_INVALID))
      end

      private

      def extract_ids
        raw_ids = @params['ids'] || @params['ids[]']
        Array(raw_ids)
          .flat_map { |value| value.to_s.split(',') }
          .map(&:strip)
          .reject(&:empty?)
          .map { |value| Integer(value, 10) }
          .uniq
      end
    end
  end
end
