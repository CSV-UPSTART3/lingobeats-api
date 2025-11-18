# frozen_string_literal: true

require 'uri'
require 'roda'
require 'slim'
require 'rack'
require 'rack/utils'
require 'slim/include'

require_relative '../presentation/views_object/songs_list'
require_relative '../presentation/views_object/search_history'

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

    ALLOWED_CATEGORIES = %w[singer song_name].freeze
    MESSAGES = {
      invalid_query: 'Invalid search query',
      search_failed: 'Error in searching songs',
      no_songs_found: 'No songs found for the given query'
    }.freeze

    def initialize(*)
      super
      cfg = App.config
      @spotify_mapper = Spotify::SongMapper
                        .new(cfg.SPOTIFY_CLIENT_ID, cfg.SPOTIFY_CLIENT_SECRET)
    end

    route do |routing|
      routing.assets   # load CSS/JS from assets plugin
      routing.public   # serve /public files
      response['Content-Type'] = 'text/html; charset=utf-8'

      # GET /
      routing.root do
        @current_page = :home

        # Get cookie viewer's previously searched
        session[:song_search_history] ||= []
        session[:singer_search_history] ||= []
        # puts "[DEBUG] data session: #{session.inspect}"

        popular = @spotify_mapper.display_popular_songs

        view 'home', locals: { popular: popular,
                               search_history: Views::SearchHistory.new(
                                 song_search_history: session[:song_search_history],
                                 singer_search_history: session[:singer_search_history] || []
                               ) }
      end

      # GET /tutorial
      routing.on 'tutorial' do
        @current_page = :tutorial
        view 'tutorial'
      end

      # GET /history
      routing.on 'history' do
        @current_page = :history
        view 'history'
      end

      # 子路由
      routing.multi_route
    end

    route('songs') do |routing|
      # POST /songs
      routing.is do
        routing.post do
          category, query = SpotifyHelper.get_params(routing)

          unless ALLOWED_CATEGORIES.include?(category) && query.to_s.strip.length.positive?
            flash[:error] = MESSAGES[:invalid_query]
            response.status = 400
            routing.redirect '/'
          end

          routing.redirect SpotifyHelper.search_path(category, query)
        end
      end

      # GET /songs/search?category=...&query=...
      routing.on 'search' do
        routing.get do
          category, query = SpotifyHelper.get_params(routing)
          songs = @spotify_mapper.public_send("search_songs_by_#{category}", query)

          # update search history in session
          SearchHistoryHelper.add_search(session, category, query)
          # puts "[DEBUG] data session: #{session.inspect}"

          view 'song', locals: { songs:, category:, query:,
                                 search_history: Views::SearchHistory.new(
                                   song_search_history: session[:song_search_history],
                                   singer_search_history: session[:singer_search_history] || []
                                 ) }
        end
      end
    end

    route('search_history') do |routing|
      # DELETE /search_history?category=...&query=...
      routing.is do
        routing.delete do
          category = routing.params['category'].to_s
          query = routing.params['query'].to_s

          SearchHistoryHelper.remove_search(session, category, query)
          response.status = 204
          routing.halt
        end
      end
    end

    route('lyrics') do |routing|
      # GET /lyrics/song?id=...&name=...&singer=...
      routing.on 'song' do
        routing.get do
          song_id, song_name, singer_name = SongLyricsService.get_params(routing)
          song_id = song_id.to_s.strip

          if song_id.empty?
            flash[:error] = MESSAGES[:invalid_query]
            response.status = 400
            routing.redirect '/'
          end

          # fetch lyrics (from DB or API)
          result = SongLyricsService.fetch_lyrics(song_id, song_name, singer_name)

          view 'lyrics_block', locals: { lyrics: result[:lyrics], cached: result[:cached] }, layout: false
        end
      end
    end

    # ===== Helper methods for Genius flow =====
    module SongLyricsService
      module_function

      def song_repo = @song_repo ||= Repository::For.klass(Entity::Song)
      def vocabulary_repo = @vocabulary_repo ||= Repository::For.klass(Entity::Vocabulary)

      def get_params(req)
        req.params.values_at('id', 'name', 'singer').map(&:to_s)
      end

      def fetch_lyrics(song_id, song_name = nil, singer_name = nil)
        # 1. get from DB
        if (hit = find_in_db(song_id))
          return hit
        end

        # 2. call api if not found in DB
        song = fetch_from_api(song_id, song_name, singer_name)
        return { lyrics: nil, cached: false } unless song

        process_song(song, cached: false)
      end

      # --- internals ---

      def find_in_db(song_id)
        song = song_repo.find_id(song_id)
        return nil unless song

        process_song(song, cached: true)
      end

      # DB 或 API 拿到 song，都走這條 pipeline
      def process_song(song, cached:)
        # 若沒有英文歌詞則直接 return
        return { lyrics: nil, cached: cached } unless song&.lyrics&.length&.positive?

        service = LingoBeats::Service::VocabularyStorageService.new(
          vocab_repo: vocabulary_repo
        )
        service.store_from_song(song)

        # 這裡以後要印 distribution 或 avg 也可以統一放這裡
        # vocabs = @vocabulary_repo.for_song(song.id)
        # distribution = vocabs.group_by(&:level).transform_values(&:count)
        # puts distribution
        # 以下兩個壞掉中...
        # puts song.difficulty_distribution
        # puts song.average_difficulty

        # 這是生歌詞的地方，但不知道前端具體要在哪裡呼叫
        # cfg = App.config
        # materials = LingoBeats::Vocabularies::Services::GenerateMaterialsForSong.new(
        #   vocabulary_repo: vocabulary_repo,
        #   mapper: LingoBeats::Gemini::VocabularyMapper.new(
        #     access_token: cfg.GEMINI_API_KEY
        #   )
        # ).call(song)


        { lyrics: song.lyrics, cached: cached }
      end

      def fetch_from_api(song_id, song_name, artist_name)
        song_repo.find_with_lyrics(
          song_id: song_id,
          song_name: song_name,
          artist_name: artist_name
        )
      end

      # 4. save in background

      # def save_in_background(song_id, lyric_value_object)
      #   Thread.new do
      #   rescue StandardError
      #     # log error but do not affect main flow
      #     App.logger.error("Failed to save lyrics for song #{song_id}")
      #   end
      # end
    end

    # ===== Helper methods for Spotify flow =====
    module SpotifyHelper
      module_function

      def get_params(req)
        req.params.values_at('category', 'query').map(&:to_s)
      end

      def search_path(category, query)
        qs = Rack::Utils.build_query('category' => category, 'query' => query)
        "/songs/search?#{qs}"
      end
    end

    # ===== Search History Helper =====
    module SearchHistoryHelper
      module_function

      def search_history_repo(session)
        LingoBeats::Repository::SearchHistories.new(session)
      end

      def add_search(session, category, query)
        repo = search_history_repo(session)
        entity = repo.load
        entity = entity.add(category:, query:)
        repo.store(entity)
      end

      def remove_search(session, category, query)
        repo = search_history_repo(session)
        entity = repo.load
        entity = entity.remove(category:, query:)
        repo.store(entity)
      end
    end
  end
end
