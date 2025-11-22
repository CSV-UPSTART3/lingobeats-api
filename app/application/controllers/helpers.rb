# frozen_string_literal: true

module LingoBeats
  module RouteHelpers
    # Application value for processing API response uniformly
    class Response
      def self.call(routing, result, representer_class)
        return handle_failure(routing, result.failure) if result.failure?

        handle_success(routing, result.value!, representer_class)
      end

      class << self
        private

        def handle_failure(routing, failure)
          failed = Representer::HttpResponse.new(failure)
          routing.halt failed.http_status_code, failed.to_json
        end

        def handle_success(routing, result, representer_class)
          http = Representer::HttpResponse.new(result)
          routing.response.status = http.http_status_code

          representer_class.new(result.message).to_json
        end
      end
    end
  end
end
