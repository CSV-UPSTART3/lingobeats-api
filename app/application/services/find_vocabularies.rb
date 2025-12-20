# frozen_string_literal: true

require 'dry/monads'

module LingoBeats
  module Service
    # Service to fetch vocabulary materials by ids
    class FindVocabularies
      include Dry::Monads::Result::Mixin

      DB_ERROR = 'Having trouble accessing the database'

      def initialize(vocabs_repo: Repository::For.klass(Entity::Vocabulary))
        super()
        @vocabs_repo = vocabs_repo
      end

      def call(ids_request:)
        ids_result = ids_request.call
        return ids_result if ids_result.failure?

        contents = @vocabs_repo.contents_by_ids(ids_result.value![:ids])
        Success(
          Response::ApiResult.new(
            status: :ok,
            message: Response::VocabulariesList.new(contents)
          )
        )
      rescue StandardError => error
        App.logger.error("[FindVocabularies] #{error.full_message}")
        Failure(Response::ApiResult.new(status: :internal_error, message: DB_ERROR))
      end
    end
  end
end
