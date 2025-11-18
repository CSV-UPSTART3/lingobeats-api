# frozen_string_literal: true

require 'dry/monads'

module LingoBeats
  module Service
    # Transaction to memorize search history when user performs a search
    class AddSearchHistory
      include Dry::Monads::Result::Mixin

      def initialize(repo: Repository::For.klass(Entity::SearchHistory))
        super()
        @repo = repo
      end

      def call(session, category, query)
        search_history = @repo.new(session).add_record(category:, query:)
        Success(search_history)
      rescue StandardError => error
        App.logger.error error.backtrace.join("\n")
        Success(@repo.load)
      end
    end
  end
end
