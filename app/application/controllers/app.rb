# frozen_string_literal: true

require 'uri'
require 'roda'
require 'rack'

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

    use Rack::MethodOverride # allows HTTP verbs beyond GET/POST (e.g., DELETE)

    route do |routing|
      routing.public # serve /public files
      response['Content-Type'] = 'application/json'

      # GET /
      routing.root do
        # Show popular songs on home page
        result = Service::ListSongs.new.call(:popular)
        RouteHelpers::Response.call(routing, result, Representer::SongsList)
      end

      # 子路由
      routing.multi_route
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
              # ...
            end
          end
        end
      end
    end
  end
end
