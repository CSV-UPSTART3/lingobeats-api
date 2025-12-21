# frozen_string_literal: true

require_relative 'progress_publisher'

module MaterialGeneration
  class JobReporter
    def initialize(config, data)
      @publisher = ProgressPublisher.new(config, data['request_id'])
    end

    def report(message)
      @publisher.publish(message)
    end
  end
end
