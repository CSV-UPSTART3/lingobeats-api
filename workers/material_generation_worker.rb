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
      job = JobReporter.new(body, MaterialGenerationWorker.config)
      service = LingoBeats::Service::MaterialGenerationService.new

      puts "[Worker] Start generating materials for song #{data.song_id}"
      job.report(GenerationMonitor.starting)
      async_rebroadcast_start(job)

      service.call(data.song_id) do |event|
        job.report(
          GenerationMonitor.progress(event[:current], event[:total])
        )
      end

      puts "[Worker] Completed job for song #{data.song_id}"
      job.report_each_second(5) { GenerationMonitor.finished }
    rescue StandardError => e
      puts "[Worker] ERROR: #{e.full_message}"
    end

    def async_rebroadcast_start(job)
      Thread.new do
        sleep(1)
        job.report(GenerationMonitor.starting)
      rescue StandardError => e
        puts "[Worker] Failed to re-broadcast start: #{e.message}"
      end
    end
  end
end
