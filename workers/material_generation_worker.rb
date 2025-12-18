# frozen_string_literal: true

require_relative 'job_reporter'
require_relative 'generation_monitor'
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

module MaterialGeneration
  # Worker for generating learning materials
  class MaterialGenerationWorker
    include Shoryuken::Worker

    def self.config
      Figaro.env
    end

    shoryuken_options queue: config.MATERIAL_QUEUE_URL,
                      auto_delete: true

    def perform(_sqs_msg, body)
      # body is JSON queue.enqueue(message)
      data = LingoBeats::Representer::MaterialJob.from_json(body)
      job = JobReporter.new(MaterialGenerationWorker.config, data)
      service = LingoBeats::Service::MaterialGenerationService.new

      puts "[Worker] Start generating materials for song #{data['song_id']}"
      job.report(GenerationMonitor.starting)

      service.call(data['song_id']) do |event|
        job.report(
          GenerationMonitor.progress(event[:current], event[:total])
        )
      end

      puts "[Worker] Completed job for song #{data['song_id']}"
      job.report(GenerationMonitor.finished)
    rescue StandardError => e
      puts "[Worker] ERROR: #{e.full_message}"
    end
  end
end
