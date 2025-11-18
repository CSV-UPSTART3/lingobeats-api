# frozen_string_literal: true

require 'dry/monads'

module LingoBeats
  module Service
    # Transaction to list search history
    class ListSearchHistories
      include Dry::Monads::Result::Mixin

      def initialize(repo: Repository::For.klass(Entity::SearchHistory))
        super()
        @repo = repo
      end

      def call(session)
        entity = @repo.new(session).load
        Success(entity)
      end
    end
  end
end
