# frozen_string_literal: true

require 'uri'
require 'roda'
require 'slim'
require 'rack'
require 'slim/include'

require_relative 'helpers'

# LingoBeats: include routing and service
module LingoBeats
  # Web App
  class App < Roda
    plugin :flash
    plugin :all_verbs # allows HTTP verbs beyond GET/POST (e.g., DELETE)
    plugin :render, engine: 'slim', views: 'app/presentation/views_html'
    plugin :public, root: 'app/presentation/public'
    plugin :assets, path: 'app/presentation/assets',
                    css: 'style.css', js: 'main.js'
    plugin :common_logger, $stderr
    plugin :halt
    plugin :multi_route

    use Rack::MethodOverride # allows HTTP verbs beyond GET/POST (e.g., DELETE)

    MESSAGES = {
      invalid_query: 'Invalid search query',
      search_failed: 'Error in searching songs',
      no_songs_found: 'No songs found for the given query'
    }.freeze

    route do |routing|
      routing.assets   # load CSS/JS from assets plugin
      routing.public   # serve /public files
      response['Content-Type'] = 'text/html; charset=utf-8'

      # GET /
      routing.root do
        @current_page = :home

        # Get cookie viewer's previously searched
        session[:song_search_history] || []
        session[:singer_search_history] || []
        history = Service::ListSearchHistories.new.call(session)
        search_history = Views::SearchHistory.new(history.value!)

        # Show popular songs on home page
        result = Service::ListSongs.new.call(:popular)
        songs, bad_message = RouteHelpers::ResultParser.parse_multi(result) do |songs, error|
          [Views::SongsList.new(songs), error]
        end

        view 'home', locals: { songs:, bad_message:, search_history: }
      end

      # 子路由
      routing.multi_route
    end

    # /tutorial
    route('tutorial') do |routing|
      routing.get do
        @current_page = :tutorial
        view 'tutorial'
      end
    end

    # /history
    route('history') do |routing|
      routing.get do
        @current_page = :history
        view 'history'
      end
    end

    # song-related routes
    route('songs') do |routing|
      # GET /songs?category=...&query=...
      routing.is do
        routing.get do
          url_request = Forms::NewSong.new.call(routing.params)
          category = url_request[:category]
          query = url_request[:query]

          result = Service::ListSongs.new.call(url_request)
          songs, bad_message = RouteHelpers::ResultParser.parse_multi(result) do |songs, error|
            [Views::SongsList.new(songs), error]
          end

          # update search history in session
          result = Service::AddSearchHistory.new.call(session, category, query)
          search_history = Views::SearchHistory.new(result.value!)

          view 'song', locals: { songs:, category:, query:, bad_message:, search_history: }
        end
      end

      # GET /songs/:id/lyrics
      routing.on String do |song_id|
        routing.on 'lyrics' do
          routing.get do
            # 1. Validate parameters
            raw_params = { 'id' => song_id }
            url_request = Forms::NewLyric.new.call(raw_params)

            # 2. Call new AddLyric pipeline
            result = Service::AddLyric.new.call(url_request)

            # 3. Parse result (success or failure)
            lyrics, bad_message = RouteHelpers::ResultParser.parse_single(result) do |lyric, error|
              [Views::Lyric.new(lyric).text, error]
            end

            view 'lyrics_block', locals: { lyrics:, bad_message: }, layout: false
          end
        end
      end

      # GET /songs/:id/materials
      # routing.on String do |song_id|
      #   routing.on 'materials' do
      #     routing.get do
      #       song = Repository::For.klass(Entity::Song).find_id(song_id)

      #       unless song
      #         routing.halt(404, "Song #{song_id} not found")
      #       end

      #       cfg = App.config

      #       materials = LingoBeats::Vocabularies::Services::GenerateMaterialsForSong.new(
      #         vocabulary_repo: Repository::For.klass(Entity::Vocabulary),
      #         mapper: LingoBeats::Gemini::VocabularyMapper.new(
      #           access_token: cfg.GEMINI_API_KEY
      #         )
      #       ).call(song)

      #       view 'materials', locals: { materials:, song: }
      #     end
      #   end
      # end
    end

    # manage search history
    route('search_history') do |routing|
      # DELETE /search_history?category=...&query=...
      routing.is do
        routing.delete do
          url_request = Forms::DeleteSearch.new.call(routing.params)
          Service::RemoveSearchHistory.new.call(session: session, request: url_request)

          response.status = 204
          routing.halt
        end
      end
    end
  end
end
