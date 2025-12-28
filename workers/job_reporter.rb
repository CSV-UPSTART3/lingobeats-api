# frozen_string_literal: true

require_relative 'progress_publisher'

module MaterialGeneration
  # Helper class to report job progress
  class JobReporter
    def initialize(request_json, config)
      job_request = LingoBeats::Representer::MaterialJob.from_json(request_json)
      channel_id = channel_for(job_request.song_id)
      @publisher = ProgressPublisher.new(config, channel_id)
    end

    def report(message)
      @publisher.publish(message)
    end

    def report_each_second(seconds, &operation)
      seconds.times do
        sleep(1)
        report(operation.call)
      end
    end

    private

    def channel_for(song_id)
      value = song_id.to_s.strip
      return '/' if value.empty?

      value.start_with?('/') ? value : "/#{value}"
    end
  end
end
