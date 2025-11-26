# frozen_string_literal: true

require 'dry/transaction'

module LingoBeats
  module Service
    # Transaction to store lyric when user selects a song
    class AddLyric
      include Dry::Transaction

      step :check_song_exists
      step :find_local_lyric
      step :fetch_remote_lyric
      step :store_lyric
      step :store_vocabularies

      def initialize(songs_repo: Repository::For.klass(Entity::Song))
        super()
        @songs_repo = songs_repo
      end

      GENIUS_API_ERROR = 'Failed to fetch lyrics'
      LYRIC_EMPTY = 'Went wrong in fetching lyrics'
      LYRIC_NOT_RECOMMENDED = 'This song is not recommended for English learners.'
      DB_ERROR = 'Having trouble accessing the database'

      private

      # step 1. check if song exists
      # :reek:FeatureEnvy
      def check_song_exists(input)
        Service::AddSong.new.call(song_id: input[:song_id]).bind do |song_result|
          song = song_result.message
          Success(input.merge(song:))
        end
      end

      # step 2. find local lyric in DB if exists
      def find_local_lyric(input)
        local_lyric = find_existing_lyric(input[:song_id])
        return Success(input.merge(local_lyric:)) if local_lyric

        Success(input) # proceed to fetch remote lyric
      end

      # step 3. if no local lyric, fetch from Genius API
      def fetch_remote_lyric(input)
        return Success(input) if input[:local_lyric]

        remote_lyric = fetch_lyric_of_song(input[:song])

        Success(input.merge(remote_lyric:))
      rescue StandardError => error
        Failure(Response::ApiResult.new(status: error.http_status, message: error.message))
      end

      # step 4. store lyric if not exists, and return lyric value object
      def store_lyric(input)
        song_id = input[:song_id]
        lyric = input[:local_lyric] || store_remote_lyric(song_id, input[:remote_lyric])
        song = @songs_repo.find_by_id(song_id)

        Success({ song:, lyric: })
      rescue StandardError => error
        Failure(Response::ApiResult.new(status: :internal_error, message: error.message))
      end

      # step 5. store vocabularies for the song lyrics
      def store_vocabularies(input)
        result = Service::AddVocabularies.new.call(input[:song])
        return Failure(result.failure) if result.failure?

        Success(Response::ApiResult.new(status: :created, message: input[:lyric]))
      end

      # support methods
      def find_existing_lyric(song_id)
        @songs_repo.find_lyric_in_database(song_id: song_id)
      rescue StandardError
        App.logger.warn('[AddLyric] Lyric does not exist for this song')
        nil # return nil, let flow continue to fetch remote
      end

      # custom error for fetch failure
      class FetchError < StandardError
        attr_reader :http_status

        def initialize(message:, http_status: :cannot_process)
          @http_status = http_status
          super(message)
        end
      end

      def fetch_lyric_of_song(song)
        lyric = @songs_repo.fetch_lyric(song_name: song.name, singer_name: song.singers.first.name)
        validate_lyric(lyric)
      rescue FetchError => error
        raise error
      rescue StandardError
        raise FetchError.new(message: GENIUS_API_ERROR, http_status: :internal_error)
      end

      def validate_lyric(lyric)
        raise FetchError.new(message: LYRIC_EMPTY) if lyric.text.strip.empty?
        raise FetchError.new(message: LYRIC_NOT_RECOMMENDED) unless lyric.english?

        lyric
      end

      def store_remote_lyric(song_id, remote_lyric)
        @songs_repo.attach_lyric(song_id: song_id, lyric_vo: remote_lyric)
      rescue StandardError => error
        App.logger.error("[AddLyric] 'Failed to store lyrics': #{error.full_message}")
        raise DB_ERROR
      end
    end
  end
end
