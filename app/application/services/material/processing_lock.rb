# frozen_string_literal: true

require 'concurrent'

module LingoBeats
  module Service
    module Material
      # Manage processing locks for material generation per song
      module ProcessingLock
        extend self

        # try to acquire lock for song_id
        # true  → can proceed processing
        # false → should skip processing
        def acquire?(song_id)
          previous = store.put_if_absent(song_id.to_s, true)
          previous.nil?
        end

        # check if song_id is being processed
        def processing?(song_id)
          store.key?(song_id.to_s)
        end

        # Optional: release the lock in certain situations (e.g., manual reset)
        def release(song_id)
          store.delete(song_id.to_s)
        end

        # Optional: clear all locks (e.g., for testing purposes)
        def reset!
          store.clear
        end

        private

        def store
          @store ||= Concurrent::Map.new
        end
      end
    end
  end
end
