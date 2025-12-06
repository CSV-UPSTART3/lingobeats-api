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
    plugin :halt
    plugin :multi_route
    plugin :caching

    route do |routing|
      response['Content-Type'] = 'application/json'

      # GET /
      routing.root do
        @current_page = :home
        response.cache_control public: true, max_age: 30
        routing.halt(200, { status: 'ok', message: 'API is working' }.to_json)
      end

      # 子路由
      routing.multi_route
    end

    # /api/v1
    route('api/v1') do |routing|
      # /songs
      routing.on 'songs' do
        routing.is do
          # GET /songs?category=...&query=...
          # return popular songs if no params
          routing.get do
            response.cache_control public: true, max_age: 300
            params = routing.params
            service = Service::ListSongs.new

            result =
              if params.empty?
                service.call(:popular)
              else
                list_req = Request::SongList.new(params)
                service.call(list_request: list_req)
              end

            RouteHelpers::Response.call(routing, result, Representer::SongsList)
          end
        end

        # /:id
        routing.on String do |song_id|
          routing.is do
            # GET /songs/:id
            routing.get do
              response.cache_control public: true, max_age: 300
              result = Service::AddSong.new.call(song_id:)

              RouteHelpers::Response.call(routing, result, Representer::Song)
            end
          end

          # /lyrics
          routing.on 'lyrics' do
            # GET /songs/:id/lyrics
            routing.get do
              response.cache_control public: true, max_age: 300
              result = Service::AddLyric.new.call(song_id:)

              RouteHelpers::Response.call(routing, result, Representer::Lyric)
            end
          end

          # /level
          routing.on 'level' do
            # GET /songs/:id/level
            routing.get do
              response.cache_control public: true, max_age: 300
              result = Service::AnalyzeSongLevel.new.call(song_id:)

              RouteHelpers::Response.call(routing, result, Representer::SongLevel)
            end
          end

          # /material
          routing.on 'material' do
            # GET /songs/:id/material
            routing.get do
              response.cache_control public: true, max_age: 300
              result = Service::GetMaterial.new.call(song_id:)

              RouteHelpers::Response.call(routing, result, Representer::Material)
            end

            # POST /songs/:id/material
            routing.post do
              incomplete = Repository::For.klass(Entity::Vocabulary).incomplete_material?(song_id)

              if incomplete
                result = Service::AddMaterial.new.call(song_id:)
                RouteHelpers::Response.call(routing, result, Representer::Material)
              else
                # convert to GET /songs/:id/material
                routing.redirect "#{App.config.API_HOST}/api/v1/songs/#{song_id}/material"
              end
            end
          end
        end
      end
    end
  end
end
