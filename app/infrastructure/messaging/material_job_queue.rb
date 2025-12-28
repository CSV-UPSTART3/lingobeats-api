# frozen_string_literal: true

module LingoBeats
  module Messaging
    # Queue for material processing jobs
    class MaterialJobQueue
      def initialize(queue_url:, aws_credentials:, queue_class: Queue)
        @queue_url = queue_url
        @aws_credentials = aws_credentials
        @queue_class = queue_class

        puts "[DEBUG] initialized with queue_url=#{@queue_url}"
      end

      # :reek:FeatureEnvy
      def enqueue(song, request_id)
        song_id = song.id
        song_name = song.name

        payload = Representer::MaterialJob.serialize(
          song_id: song_id,
          request_id: request_id
        )
        queue_client.send(payload)

        App.logger.info("[MaterialJobQueue] queued material job for song=#{song_name}, song_id=#{song_id}")
      end

      private

      def queue_client
        @queue_client ||= @queue_class.new(
          queue_url: @queue_url,
          aws_credentials: @aws_credentials
        )
      end
    end
  end
end
