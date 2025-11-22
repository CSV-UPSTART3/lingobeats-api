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

      LYRIC_NOT_EXISTS = 'Lyric does not exist for this song'
      GENIUS_API_ERROR = 'Failed to load lyrics'
      LYRIC_EMPTY = 'Went wrong in fetching lyrics'
      LYRIC_NOT_RECOMMENDED = 'This song is not recommended for English learners.'
      LYRIC_STORE_ERROR = 'Failed to store lyrics'
      DB_ERROR = 'Having trouble accessing the database'

      private

      # step 1. check if song exists
      def check_song_exists(input)
        add_song_result = Service::AddSong.new.call(song_id: input[:song_id])
        return Failure(add_song_result.failure) if add_song_result.failure?

        Success(input)
      end

      # step 2. find local lyric in DB if exists
      def find_local_lyric(input)
        existing_lyric = find_existing_lyric(input[:song_id])
        return Success(input.merge(local_lyric: existing_lyric)) if existing_lyric

        Success(input) # proceed to fetch remote lyric
      end

      # step 3. if no local lyric, fetch from Genius API
      def fetch_remote_lyric(input)
        return Success(input) if input[:local_lyric]

        remote_lyric = fetch_lyric_of_song(fetch_song(input))

        Success(input.merge(remote_lyric: remote_lyric))
      rescue StandardError => error
        Failure(Response::ApiResult.new(status: :not_found, message: error.message))
      end

      # step 4. store lyric if not exists, and return lyric value object
      def store_lyric(input)
        song_id = input[:song_id]
        lyric = input[:local_lyric] || store_remote_lyric(song_id, input[:remote_lyric])

        Success({ song_id: song_id, lyric: lyric })
      rescue StandardError => error
        App.logger.error("[AddLyric] #{LYRIC_STORE_ERROR}: #{error.message}")
        Failure(Response::ApiResult.new(status: :internal_error, message: DB_ERROR))
      end

      # step 5. store vocabularies for the song lyrics
      def store_vocabularies(input)
        result = Service::AddVocabularies.new.call(fetch_song(input))
        return Failure(result.failure) if result.failure?

        Success(Response::ApiResult.new(status: :created, message: input[:lyric]))
      end

      # support methods
      def find_existing_lyric(song_id)
        @songs_repo.find_lyric_in_database(song_id: song_id)
      rescue StandardError
        App.logger.warn("[AddLyric] #{LYRIC_NOT_EXISTS}")
        nil # return nil, let flow continue to fetch remote
      end

      # custom error for fetch failure
      class FetchError < StandardError; end

      def fetch_song(input)
        AddSong::SongFinder.new(@songs_repo).find_song(input[:song_id])
      end

      def fetch_lyric_of_song(song)
        lyric = @songs_repo.fetch_lyric(song_name: song.name, singer_name: song.singers.first.name)
        validate_lyric(lyric)
      rescue FetchError => error
        raise error
      rescue StandardError
        raise FetchError, GENIUS_API_ERROR
      end

      def validate_lyric(lyric)
        raise FetchError, LYRIC_EMPTY if lyric.text.strip.empty?
        raise FetchError, LYRIC_NOT_RECOMMENDED unless lyric.english?

        lyric
      end

      def store_remote_lyric(song_id, remote_lyric)
        @songs_repo.attach_lyric(song_id: song_id, lyric_vo: remote_lyric)
      end
    end
  end
end
