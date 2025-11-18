# frozen_string_literal: true

require 'dry/transaction'

module LingoBeats
  module Service
    # Transaction to store lyric when user selects a song
    class AddLyric
      include Dry::Transaction
      include Dry::Monads[:result]

      step :parse_url
      step :find_lyric
      step :check_song_exists
      step :store_lyric

      def initialize(songs_repo: Repository::For.klass(Entity::Song))
        super()
        @songs_repo = songs_repo
      end

      private

      # step 1. parse id/name/singer from request URL
      def parse_url(input)
        return Failure("URL #{input.errors.messages.first}") unless input.success?

        params = ParamExtractor.call(input)
        Success(params)
      end

      # step 2. find if lyric already exists in db, else fetch from Genius API
      def find_lyric(input)
        if (lyric_vo = lyric_in_database(input))
          input[:local_lyric] = lyric_vo
        else
          input[:remote_lyric] = fetch_song_of_lyric(input)
        end
        Success(input)
      rescue FetchError => error
        Failure(error.message)
      rescue StandardError => error
        Failure(error.to_s)
      end

      # step 3. check if song exists
      def check_song_exists(input)
        add_song_result = Service::AddSong.new.call(input[:song_id])
        return Failure(add_song_result.failure) if add_song_result.failure?

        Success(input)
      rescue StandardError => error
        Failure(error.to_s)
      end

      # step 4. store lyric if not exists, and return lyric value object
      def store_lyric(input)
        song_id      = input[:song_id]
        local_lyric  = input[:local_lyric]
        remote_lyric = input[:remote_lyric]

        # 1. 如果 DB 中已經有 lyrics，就直接使用，不要覆蓋
        lyric =
          if local_lyric
            local_lyric
          else
            # 2. 沒有 DB lyrics → 用 remote 寫入資料庫
            @songs_repo.attach_lyric(song_id: song_id, lyric_vo: remote_lyric)
          end
        
        # 3. vocabulary pipeline（使用實際用的 lyric，不是 remote_lyric）
        # --- ADDED: integrate your vocabulary storage pipeline (from old_app.rb) ---
        if lyric&.text&.length&.positive?
          vocab_service = LingoBeats::Service::VocabularyStorageService.new(
            vocab_repo: Repository::For.klass(Entity::Vocabulary)
          )
          vocab_service.store_from_song(
            @songs_repo.find_id(input[:song_id])
          )
        end
        # ---------------------------------------------------------------------------

        Success(lyric)
        # return Success(input[:local_lyric]) if input[:local_lyric]

        # lyric = @songs_repo.attach_lyric(song_id: input[:song_id], lyric_vo: input[:remote_lyric])

        # Success(lyric)
      rescue StandardError => error
        App.logger.error error.backtrace.join("\n")
        Failure('Failed to store lyric to database')
      end

      # support methods
      def lyric_in_database(input)
        @songs_repo.find_lyric_in_database(song_id: input[:song_id])
      rescue StandardError => error
        raise error.message
      end

      # custom error for fetch failure
      class FetchError < StandardError; end

      def fetch_song_of_lyric(input)
        lyric = @songs_repo.fetch_lyric(song_name: input[:song_name], singer_name: input[:singer_name])
        validate_lyric(lyric)
      rescue FetchError => error
        raise error
      rescue StandardError
        raise FetchError, 'Failed to load lyrics.'
      end

      def validate_lyric(lyric)
        raise FetchError, 'Went wrong in fetching lyrics.' if lyric.nil? || lyric.text.strip.empty?
        raise FetchError, 'This song is not recommended for English learners.' unless lyric.english?

        lyric
      end

      # parameter extractor
      class ParamExtractor
        def self.call(request)
          params = request.to_h
          { song_id: params[:id], song_name: params[:name], singer_name: params[:singer] }
        end
      end
    end
  end
end
