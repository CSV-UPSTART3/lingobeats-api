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
      routing.root do
        @current_page = :home
        routing.halt(200, { status: 'ok', message: 'API is working' }.to_json)
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

    # /api/v1
    route('api/v1') do |routing|
      # /songs
      routing.on 'songs' do
        routing.is do
          # GET /songs?category=...&query=...
          # return popular songs if no params
          routing.get do
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
              result = Service::AddSong.new.call(song_id:)

              RouteHelpers::Response.call(routing, result, Representer::Song)
            end
          end

          # /lyrics
          routing.on 'lyrics' do
            # GET /songs/:id/lyrics
            routing.get do
              result = Service::AddLyric.new.call(song_id:)

              RouteHelpers::Response.call(routing, result, Representer::Lyric)
            end
          end

          # /level
          routing.on 'level' do
            # GET /songs/:id/level
            routing.get do
              result = Service::AnalyzeSongLevel.new.call(song_id:)

              RouteHelpers::Response.call(routing, result, Representer::SongLevel)
            end
          end

          # /material
          routing.on 'material' do
            # GET /songs/:id/material
            routing.get do
              result = Service::GetMaterial.new.call(song_id:)

              RouteHelpers::Response.call(routing, result, Representer::Material)
            end

            # POST /songs/:id/material
            routing.post do
              incomplete = Repository::For.klass(Entity::Vocabulary).incomplete_material?(song_id)

              result =
                if incomplete
                  # there are vocabularies without materials, generate them
                  Service::AddMaterial.new.call(song_id:)
                else
                  # all vocabularies have materials, just return them
                  Service::GetMaterial.new.call(song_id:)
                end

              RouteHelpers::Response.call(routing, result, Representer::Material)
            end
          end
        end
      end
    end
  end
end
