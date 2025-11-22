# frozen_string_literal: true

require 'dry/transaction'

module LingoBeats
  module Service
    # Transaction to store lyric when user selects a song
    class AddLyric
      include Dry::Transaction

      step :parse_url
      step :check_song_exists
      step :find_local_lyric
      step :fetch_remote_lyric
      step :store_lyric
      step :store_vocabularies

      def initialize(songs_repo: Repository::For.klass(Entity::Song))
        super()
        @songs_repo = songs_repo
      end

      private

      # step 1. parse id/name/singer from request URL
      def parse_url(input)
        return Failure("URL #{input.errors.messages.first}") unless input.success?

        params = ParamExtractor.call(input)
        Success(params)
      end

      # step 2. check if song exists
      def check_song_exists(input)
        add_song_result = Service::AddSong.new.call(input[:song_id])
        return Failure(add_song_result.failure) if add_song_result.failure?

        Success(input)
      rescue StandardError => error
        Failure("Failed to verify song: #{error.message}")
      end

      # step 3-1. find local lyric in DB if exists
      def find_local_lyric(input)
        existing_lyric = find_existing_lyric(input[:song_id])
        return Success(input.merge(local_lyric: existing_lyric)) if existing_lyric

        Success(input) # proceed to fetch remote lyric
      end

      # step 3-2. if no local lyric, fetch from Genius API
      def fetch_remote_lyric(input)
        return Success(input) if input[:local_lyric]

        remote_lyric = fetch_song_of_lyric(fetch_song(input))
        Success(input.merge(remote_lyric: remote_lyric))
      rescue StandardError => error
        Failure(error.message)
      end

      # step 4. store lyric if not exists, and return lyric value object
      def store_lyric(input)
        song_id = input[:song_id]
        lyric = input[:local_lyric] || store_remote_lyric(song_id, input[:remote_lyric])
        Success({ song_id: song_id, lyric: lyric })
      rescue StandardError => error
        handle_store_error(error, 'lyric')
      end

      # step 5. store vocabularies for the song lyrics
      def store_vocabularies(input)
        result = Service::AddVocabularies.new.call(fetch_song(input))
        raise StandardError, result.failure if result.failure?

        Success(input[:lyric])
      rescue StandardError => error
        handle_store_error(error, 'vocabularies')
      end

      # support methods
      def find_existing_lyric(song_id)
        @songs_repo.find_lyric_in_database(song_id: song_id)
      rescue StandardError => error
        App.logger.warn("Error checking existing lyric: #{error.message}")
        nil # return nil, let flow continue to fetch remote
      end

      # custom error for fetch failure
      class FetchError < StandardError; end

      def fetch_song(input)
        @songs_repo.find_id(input[:song_id])
      rescue StandardError => error
        App.logger.error("Error fetching song: #{error.message}")
        raise 'Error fetching song.'
      end

      def fetch_song_of_lyric(song)
        lyric = @songs_repo.fetch_lyric(song_name: song.name, singer_name: song.singers.first.name)
        validate_lyric(lyric)
      rescue FetchError => error
        raise error
      rescue StandardError
        raise FetchError, 'Failed to load lyrics.'
      end

      def validate_lyric(lyric)
        raise FetchError, 'Went wrong in fetching lyrics.' if lyric.text.strip.empty?
        raise FetchError, 'This song is not recommended for English learners.' unless lyric.english?

        lyric
      end

      def store_remote_lyric(song_id, remote_lyric)
        @songs_repo.attach_lyric(song_id: song_id, lyric_vo: remote_lyric)
      end

      def handle_store_error(error, object_name)
        App.logger.error("Failed to store #{object_name}: #{error.message}")
        Failure('Error in connecting to database.')
      end

      # parameter extractor
      class ParamExtractor
        def self.call(request)
          params = request.to_h
          { song_id: params[:id] }
        end
      end
    end
  end
end
