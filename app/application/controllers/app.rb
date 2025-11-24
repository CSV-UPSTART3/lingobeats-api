# frozen_string_literal: true

require 'roda'
require 'rack' # for Rack::MethodOverride

require_relative 'helpers'

# LingoBeats: include routing and service
module LingoBeats
  # Web App
  class App < Roda
    plugin :flash
    plugin :all_verbs # allows HTTP verbs beyond GET/POST (e.g., DELETE)
    plugin :public, root: 'app/presentation/public'
    plugin :halt
    plugin :multi_route

    route do |routing|
      routing.public # serve /public files
      response['Content-Type'] = 'application/json'

      # GET /
      routing.root do # Roda routing.root is for GET /
        @current_page = :home

        # Show popular songs on home page
        result = Service::ListSongs.new.call(:popular)
        RouteHelpers::Response.call(routing, result, Representer::SongsList)
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

    route('api/v1') do |routing|
      # song-related routes
      routing.on 'songs' do
        # GET /songs?category=...&query=...
        routing.is do
          routing.get do
            list_req = Request::SongList.new(routing.params)
            result = Service::ListSongs.new.call(list_request: list_req)

            RouteHelpers::Response.call(routing, result, Representer::SongsList)
          end
        end

        # /:id
        routing.on String do |song_id|
          # GET /songs/:id
          routing.is do
            routing.get do
              result = Service::AddSong.new.call(song_id:)

              RouteHelpers::Response.call(routing, result, Representer::Song)
            end
          end

          # GET /songs/:id/lyrics
          routing.on 'lyrics' do
            routing.get do
              result = Service::AddLyric.new.call(song_id:)

              RouteHelpers::Response.call(routing, result, Representer::Lyric)
            end
          end

          # GET /songs/:id/level
          routing.on 'level' do
            routing.get do
              result = Service::AnalyzeSongLevel.new.call(song_id:)

              RouteHelpers::Response.call(routing, result, Representer::SongLevel)
            end
          end

          # POST /songs/:id/materials
          routing.on 'materials' do
            routing.post do
              result = Service::AddMaterial.new.call(song_id:)

              RouteHelpers::Response.call(routing, result, Representer::Material)
            end
            # GET /songs/:id/materials
            routing.get do
              result = Service::GetMaterials.new.call(song_id:)

              RouteHelpers::Response.call(routing, result, Representer::Material)
            end
          end
        end
      end
    end
  end
end
