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
      context = build_context(body)

      start_job(context)
      run_generation(context)
      finish_job(context)
    rescue StandardError => e
      handle_error(e)
    end

    def build_context(body)
      data = LingoBeats::Presenter::MaterialJob.from_json(body)

      {
        data: data,
        job: JobReporter.new(body, MaterialGenerationWorker.config),
        service: LingoBeats::Service::MaterialGenerationService.new
      }
    end

    def start_job(context)
      data = context[:data]
      job  = context[:job]

      puts "[Worker] Start generating materials for song #{data.song_id}"
      job.report(GenerationMonitor.starting)
      async_rebroadcast_start(job)
    end

    def run_generation(context)
      data    = context[:data]
      job     = context[:job]
      service = context[:service]

      service.call(data.song_id) do |event|
        job.report(
          GenerationMonitor.progress(event[:current], event[:total])
        )
      end
    end

    def finish_job(context)
      data = context[:data]
      job  = context[:job]

      puts "[Worker] Completed job for song #{data.song_id}"
      job.report_each_second(5) { GenerationMonitor.finished }
    end

    def handle_error(error)
      puts "[Worker] ERROR: #{error.full_message}"
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
