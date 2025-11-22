# frozen_string_literal: true

require 'dry/transaction'

module LingoBeats
  module Service
    # Transaction to return list of songs
    class ListSongs
      include Dry::Transaction

      step :validate_list
      step :fetch_songs

      def initialize(mapper: nil)
        super()
        mapper ||= Spotify::SongMapper.new(App.config.SPOTIFY_CLIENT_ID, App.config.SPOTIFY_CLIENT_SECRET)
        @song_provider = SongProvider.new(mapper)
      end

      SPOTIFY_API_ERROR = "Failed to load songs.\nPlease try again later."
      EMPTY_SONG_RESULT = 'No results for' # concatenated with query later

      private

      # step 1. parse category and query from request URL
      def validate_list(input)
        return Success(popular: true) if input == :popular

        list_request = input[:list_request].call
        return Failure(list_request.failure) if list_request.failure?

        Success(list_request.value!)
      end

      # step 2. fetch songs from Spotify API
      def fetch_songs(input)
        @song_provider.fetch(input)
                      .then { |songs| Response::SongsList.new(songs) }
                      .then { |songs_list| Success(Response::ApiResult.new(status: :created, message: songs_list)) }
      rescue StandardError => error
        Failure(Response::ApiResult.new(status: :internal_error, message: error.to_s))
      end

      # fetch songs from Spotify API
      class SongProvider
        # custom error for fetch failure
        class FetchError < StandardError; end

        def initialize(mapper)
          @mapper = mapper
        end

        def fetch(input)
          songs =
            if input[:popular]
              fetch_trends
            else
              fetch_search_results(input)
            end
          validate_songs(songs, input)
        rescue FetchError
          raise SPOTIFY_API_ERROR
        end

        def fetch_trends
          @mapper.search_popular_songs
        rescue StandardError
          raise FetchError
        end

        def fetch_search_results(input)
          @mapper.public_send("search_songs_by_#{input[:category]}", input[:query])
        rescue StandardError
          raise FetchError
        end

        private

        def validate_songs(songs, input)
          raise "#{EMPTY_SONG_RESULT} \"#{input[:query]}\"" if songs.empty?

          songs
        end
      end
    end
  end
end
