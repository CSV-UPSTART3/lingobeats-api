# frozen_string_literal: true

require 'dry/transaction'

module LingoBeats
  module Service
    # Transaction to return list of songs
    class ListSongs
      include Dry::Transaction

      step :parse_url
      step :fetch_songs

      def initialize(mapper: nil)
        super()
        mapper ||= Spotify::SongMapper.new(App.config.SPOTIFY_CLIENT_ID, App.config.SPOTIFY_CLIENT_SECRET)
        @song_provider = SongProvider.new(mapper)
      end

      private

      # step 1. parse category and query from request URL
      def parse_url(input)
        return Success(popular: true) if input == :popular
        return Failure("URL #{input.errors.messages.first}") unless input.success?

        params = ParamExtractor.call(input)
        Success(params)
      end

      # step 2. fetch songs from Spotify API
      def fetch_songs(input)
        songs = @song_provider.fetch(input)
        Success(songs)
      rescue StandardError => error
        App.logger.error error.backtrace.join("\n")
        Failure(error.to_s)
      end

      # parameter extractor
      class ParamExtractor
        def self.call(request)
          params = request.to_h
          { category: params[:category], query: params[:query] }
        end
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
          raise "Failed to load songs.\nPlease try again later."
        end

        def fetch_trends
          @mapper.search_popular_songs
        rescue StandardError
          raise FetchError
        end

        private

        def fetch_search_results(input)
          @mapper.public_send("search_songs_by_#{input[:category]}", input[:query])
        rescue StandardError
          raise FetchError
        end

        def validate_songs(songs, input)
          raise "No results for \"#{input[:query]}\"" if songs.empty?

          songs
        end
      end
    end
  end
end
