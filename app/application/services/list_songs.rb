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
                      .then { |songs_list| Success(Response::ApiResult.new(status: :ok, message: songs_list)) }
      rescue StandardError => error
        Failure(Response::ApiResult.new(status: error.http_status, message: error.message))
      end

      # fetch songs from Spotify API
      class SongProvider
        # custom error base class
        class BaseError < StandardError
          attr_reader :http_status

          def initialize(message:, http_status: :internal_error)
            @http_status = http_status
            super(message)
          end
        end

        class FetchError < BaseError; end
        class EmptyError < BaseError; end

        SPOTIFY_API_ERROR = 'Failed to load songs.'
        EMPTY_SONG_RESULT = 'No results for' # concatenated with query later

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
          raise FetchError.new(message: SPOTIFY_API_ERROR)
        end

        def fetch_trends
          @mapper.search_popular_songs
        rescue StandardError => error
          raise FetchError.new(message: error.message)
        end

        def fetch_search_results(input)
          @mapper.public_send("search_songs_by_#{input[:category]}", input[:query])
        rescue StandardError => error
          raise FetchError.new(message: error.message)
        end

        private

        def validate_songs(songs, input)
          if songs.empty?
            raise EmptyError.new(
              message: "#{EMPTY_SONG_RESULT} \"#{input[:query]}\"",
              http_status: :not_found
            )
          end

          songs
        end
      end
    end
  end
end
