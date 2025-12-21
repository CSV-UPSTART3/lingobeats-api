# frozen_string_literal: true

require 'http'

module MaterialGeneration
  class ProgressPublisher
    def initialize(config, channel_id)
      @config = config
      @channel_id = channel_id
    end

    def publish(message)
      puts "Progress: #{message}"
      puts "[post: #{@config.API_HOST}/faye]}"
      puts "Channel: #{@channel_id}"
      HTTP.headers(content_type: 'application/json')
          .post(
            "#{@config.API_HOST}/faye",
            body: message_body(message)
          )
          .then { |result| puts "(#{result.status})"}
    rescue HTTP::ConnectionError
      puts '(Faye server not found - progress not sent)'
    end

    private

    def message_body(message)
      {
        channel: @channel_id,
        data: message
      }.to_json
    end
  end
end
