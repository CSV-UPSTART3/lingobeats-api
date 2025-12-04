# frozen_string_literal: true

require_relative '../../helpers/spec_helper'
require_relative '../../helpers/vcr_helper'
require_relative '../../helpers/database_helper'
require 'rack/test'

def app
  LingoBeats::App
end

describe 'Test LingoBeats API routes' do
    include Rack::Test::Methods

    VcrHelper.setup_vcr

    before do
        VcrHelper.configure_vcr_for_spotify
        VcrHelper.configure_vcr_for_genius
        VcrHelper.configure_vcr_for_gemini
        DatabaseHelper.wipe_database
    end

    after do
        VcrHelper.eject_vcr
        VcrHelper.eject_vcr
        VcrHelper.eject_vcr
    end

    describe 'Root route' do
        it 'successfully returns root information' do
        get '/'

        _(last_response.status).must_equal 200

        body = JSON.parse(last_response.body)
        _(body['status']).must_equal 'ok'
        _(body['message']).must_include 'API is working'
        end
    end

    describe 'Songs routes' do
        describe 'GET /api/v1/songs' do
            it 'returns popular songs when no params given' do
                get '/api/v1/songs'

                _(last_response.status).must_equal 200

                body = JSON.parse(last_response.body)

                _(body).must_include 'songs'
                songs = body['songs']
                _(songs).must_be_kind_of Array

                unless songs.empty?
                    first = songs.first
                    # 對應 Song representer 裡的 property
                    _(first).must_include 'id'
                    _(first).must_include 'name'
                    _(first).must_include 'uri'
                    _(first).must_include 'external_url'
                    _(first).must_include 'album_name'
                end
            end

            it 'returns filtered songs when query is given' do
                get '/api/v1/songs', { category: 'song_name', query: 'Golden' }

                _(last_response.status).must_equal 200

                body = JSON.parse(last_response.body)
                _(body).must_include 'songs'

                songs = body['songs']
                _(songs).must_be_kind_of Array
            end
        end

        describe 'GET /api/v1/songs/:id' do
            it 'returns song info for a valid song id' do
                LingoBeats::Service::AddSong.new.call(song_id: SONG_ID)

                get "/api/v1/songs/#{SONG_ID}"

                _(last_response.status).must_equal 200
                body = JSON.parse(last_response.body)
                song = body
                _(song['id']).wont_be_nil
                _(song['name']).wont_be_nil
                _(song['uri']).wont_be_nil
                _(song['album_name']).wont_be_nil
            end

            it 'returns 500 for a non-existent song id' do
                get '/api/v1/songs/non-existent-id-123'

                _(last_response.status).must_equal 500

                body = JSON.parse(last_response.body)
            end
        end

        describe 'GET /api/v1/songs/:id/lyrics' do
            #SONG_ID = ENV.fetch('TEST_SONG_ID', '3XVozq1aeqsJwpXrEZrDJ9')

            it 'returns lyrics for an existing song' do
                LingoBeats::Service::AddSong.new.call(song_id: SONG_ID)
                #LingoBeats::Service::AddLyric.new.call(song_id: SONG_ID)

                get "/api/v1/songs/#{SONG_ID}/lyrics"

                #puts "STATUS: #{last_response.status}"
                #puts "BODY:   #{last_response.body}"

                _(last_response.status).must_equal 200
                

                body = JSON.parse(last_response.body)

                _(body).must_include 'text'
            end

            it 'returns 500 for lyrics of a non-existent song' do
                get '/api/v1/songs/non-existent-id-123/lyrics'

                _(last_response.status).must_equal 500

                body = JSON.parse(last_response.body)
            end
        end

        describe 'GET /api/v1/songs/:id/level' do
            it 'returns song level info for an existing song' do
                # 先確定 DB 有這首歌 + 它的 vocab（AnalyzeSongLevel 才有東西算）
                LingoBeats::Service::AddSong.new.call(song_id: SONG_ID)
                LingoBeats::Service::AddLyric.new.call(song_id: SONG_ID)

                get "/api/v1/songs/#{SONG_ID}/level"

                # puts "STATUS: #{last_response.status}"
                # puts "BODY:   #{last_response.body}"

                _(last_response.status).must_equal 200

                body = JSON.parse(last_response.body)

                _(body).must_include 'distribution'
                _(body).must_include 'level'
            end

            it 'returns error for non-existent song id' do
                get '/api/v1/songs/non-existent-id-123/level'

                # puts "STATUS(non-existent): #{last_response.status}"
                # puts "BODY(non-existent):   #{last_response.body}"

                _(last_response.status).must_equal 404 
            end
        end

        describe 'GET /api/v1/songs/:id/material' do
            it 'returns materials for an existing song' do
                # 1) 先把歌 + 歌詞 + vocab 建好（不產 material）
                LingoBeats::Service::AddSong.new.call(song_id: SONG_ID)
                LingoBeats::Service::AddLyric.new.call(song_id: SONG_ID)
                # AddLyric 會順便跑 AddVocabularies，這樣 DB 就有 vocabs 但 material = nil

                # 2) 用 vocab repo 手動塞 material
                vocabs_repo = LingoBeats::Repository::For.klass(LingoBeats::Entity::Vocabulary)
                vocabs      = vocabs_repo.for_song(SONG_ID)

                # 避免 spec 在還沒建 vocab 時就炸
                _(vocabs).wont_be_empty

                vocabs.each do |v|
                    fake_json = {
                        word: v.name,
                        entries: [
                        { meaning: "fake meaning for #{v.name}",
                            example: "fake example for #{v.name}" }
                        ]
                    }.to_json

                    vocabs_repo.update_material(v.id, fake_json)
                end


                get "/api/v1/songs/#{SONG_ID}/material"

                #puts "STATUS(material GET): #{last_response.status}"
                #puts "BODY(material GET):   #{last_response.body}"

                _(last_response.status).must_equal 200

                body = JSON.parse(last_response.body)

                _(body).must_include 'song'
                _(body).must_include 'contents'

                first = body['contents'].first
                _(first).must_include 'word'
                _(first).must_include 'entries'
            end

            it 'returns 404 for materials of a non-existent song' do
                get '/api/v1/songs/non-existent-id-123/material'

                #puts "STATUS(material GET non-existent): #{last_response.status}"
                #puts "BODY(material GET non-existent):   #{last_response.body}"

                _(last_response.status).must_equal 404

                body = JSON.parse(last_response.body)
                _(body['status']).must_equal 'not_found'
                _(body['message']).wont_be_nil
            end
        end

        describe 'POST /api/v1/songs/:id/material' do
            it 'returns materials when all vocabularies already have material' do
                # 1) song + lyric + vocabs
                LingoBeats::Service::AddSong.new.call(song_id: SONG_ID)
                LingoBeats::Service::AddLyric.new.call(song_id: SONG_ID)

                # 2) 手動幫所有 vocabs 塞 material
                vocabs_repo = LingoBeats::Repository::For.klass(LingoBeats::Entity::Vocabulary)
                vocabs      = vocabs_repo.for_song(SONG_ID)
                _(vocabs).wont_be_empty

                vocabs.each do |v|
                    fake_json = {
                        word: v.name,
                        entries: [
                        { meaning: "fake meaning for #{v.name}",
                            example: "fake example for #{v.name}" }
                        ]
                    }.to_json

                    vocabs_repo.update_material(v.id, fake_json)
                end

                # 3) 這時 incomplete_material? 應該是 false → route 會走 GetMaterial
                post "/api/v1/songs/#{SONG_ID}/material"

                _(last_response.status).must_equal 200

                body = JSON.parse(last_response.body)
                _(body).must_include 'song'
                _(body).must_include 'contents'
                _(body['contents']).wont_be_empty
            end
            it 'creates materials via AddMaterial when some vocabularies have no material yet' do
                # 1) 先準備「有 vocabs 但還沒有 material」的狀態
                LingoBeats::Service::AddSong.new.call(song_id: SONG_ID)
                LingoBeats::Service::AddLyric.new.call(song_id: SONG_ID)
                # 到這裡為止，vocab 都還是 material = nil → incomplete_material? 應該會是 true

                # 2) 做一個假的 AddMaterial service，完全不打 Gemini
                fake_add_material = Class.new do
                    class << self
                    attr_accessor :called_with
                    end

                    def initialize(*); end

                    def call(song_id:)
                    self.class.called_with = song_id

                    fake_material = LingoBeats::Response::Material.new(
                        song: 'Golden',
                        contents: [
                        {
                            word: 'take',
                            entries: [
                            { meaning: 'fake meaning', example: 'fake example' }
                            ]
                        }
                        ]
                    )

                    fake_result = LingoBeats::Response::ApiResult.new(
                        status: :created,
                        message: fake_material
                    )

                    Dry::Monads::Result::Success.new(fake_result)
                    end
                end

                # 3) 把真的 AddMaterial 暫時換成 fake 版
                original = LingoBeats::Service.const_get(:AddMaterial)

                begin
                    LingoBeats::Service.send(:remove_const, :AddMaterial)
                    LingoBeats::Service.const_set(:AddMaterial, fake_add_material)

                    # 4) 打 POST /material：這裡 route 會 new fake_add_material 而不是原本那個
                    post "/api/v1/songs/#{SONG_ID}/material"

                    #puts "STATUS(material POST create): #{last_response.status}"
                    #puts "BODY(material POST create):   #{last_response.body}"

                    _(last_response.status).must_equal 201

                    body = JSON.parse(last_response.body)

                    # Representer::Material → { "song": "...", "contents": [...] }
                    _(body).must_include 'song'
                    _(body['song']).must_be_kind_of String

                    _(body).must_include 'contents'
                    _(body['contents']).must_be_kind_of Array
                    _(body['contents']).wont_be_empty

                    first = body['contents'].first
                    _(first).must_include 'word'
                    _(first).must_include 'entries'

                    # 確認 route 有把正確的 song_id 丟給 AddMaterial
                    _(fake_add_material.called_with).must_equal SONG_ID
                ensure
                    # 5) 把真的 AddMaterial 放回去，避免影響其他測試
                    LingoBeats::Service.send(:remove_const, :AddMaterial)
                    LingoBeats::Service.const_set(:AddMaterial, original)
                end
            end
        end
    end
end