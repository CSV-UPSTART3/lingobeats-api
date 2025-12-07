# frozen_string_literal: true

require_relative '../require_app'
require_app

require 'figaro'
require 'shoryuken'

# ensure worker itself can load config/secrets.yml
Figaro.application = Figaro::Application.new(
  environment: ENV['RACK_ENV'] || 'development',
  path: File.expand_path('../config/secrets.yml', __dir__)
)
Figaro.load

class MaterialGenerationWorker
  include Shoryuken::Worker

  def self.config
    Figaro.env
  end

  shoryuken_options queue: config.MATERIAL_QUEUE_URL,
                    auto_delete: true

  def perform(sqs_msg, body)
    # body is JSON queue.enqueue(message)
    data = LingoBeats::Representer::MaterialJob.from_json(body)

    puts "[Worker] Start generating materials for song #{data['song_id']}"

    service = LingoBeats::Service::MaterialGenerationService.new
    service.call(data['song_id'])

    puts "[Worker] Completed job for song #{data['song_id']}"
  rescue StandardError => e
    puts "[Worker] ERROR: #{e.full_message}"
  end
end
