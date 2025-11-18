# frozen_string_literal: true

require 'dry/transaction'

module LingoBeats
  module Service
    # Transaction to remove search history when user deletes a search
    class RemoveSearchHistory
      include Dry::Transaction

      step :parse_url
      step :remove_search

      def initialize(repo: Repository::For.klass(Entity::SearchHistory))
        super()
        @repo = repo
      end

      private

      # step 1. parse category and query from request URL
      def parse_url(input)
        req = input[:request]
        return Failure("URL #{req.errors.messages.first}") unless req.success?

        params = ParamExtractor.call(req)
        Success(session: input[:session], params: params)
      end

      # step 2. remove search from history
      def remove_search(input)
        session = input[:session]
        params = input[:params]

        search_history = @repo.new(session).remove_record(category: params[:category], query: params[:query])
        Success(search_history)
      rescue StandardError => error
        App.logger.error error.backtrace.join("\n")
        Success(@repo.load)
      end

      # parameter extractor
      class ParamExtractor
        def self.call(request)
          params = request.to_h
          { category: params[:category], query: params[:query] }
        end
      end
    end
  end
end
