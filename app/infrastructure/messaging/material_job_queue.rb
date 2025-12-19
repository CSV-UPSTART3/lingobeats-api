# frozen_string_literal: true

module LingoBeats
  module Messaging
    # Queue for material processing jobs
    class MaterialJobQueue
      def initialize(config: App.config)
        @config = config
        @queue_url = @config.MATERIAL_QUEUE_URL
        @queue_class = Queue

        puts "[DEBUG] initialized with queue_url=#{@queue_url}"
      end

      def enqueue(song, request_id)
        payload = Representer::MaterialJob.new(song_id: song.id, request_id: request_id)
                                          .to_json

        queue_client.send(payload)

        App.logger.info("[MaterialJobQueue] queued material job for song=#{song.name}, song_id=#{song.id}")
      end

      private

      def queue_client
        @queue_client ||= @queue_class.new(@queue_url, @config)
      end
    end
  end
end
