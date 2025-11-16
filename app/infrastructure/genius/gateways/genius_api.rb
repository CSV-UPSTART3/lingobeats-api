# frozen_string_literal: true

require 'http'

module LingoBeats
  module Genius
    # Handles communication with the Genius API.
    class Api
      BASE = 'https://api.genius.com'

      def initialize(token_provider:)
        @http = HTTP.headers(
          'Authorization' => "Bearer #{token_provider.access_token}",
          'User-Agent' => 'Mozilla/5.0 (compatible; LingoBeats/1.0; +https://github.com/CSV-UPSTART3)'
        )
      end

      # 從 Genius 給的歌曲網址把 HTML 抓回來
      # 回傳 Nokogiri::HTML::Document 或 nil
      def fetch_lyrics_html(url)
        # 透過 Cloudflare Worker proxy 來繞過 Cloudflare 保護
        proxy_url = "https://lingobeats-proxy.vick-fan.workers.dev/?url=#{URI.encode_www_form_component(url)}"

        plain_http = HTTP.headers(
          'User-Agent' => 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0 Safari/537.36'
        )

        response = plain_http.follow(max_hops: 3).get(proxy_url)
        # App.logger.info "[Genius] fetch_lyrics_html via proxy status=#{response.status} size=#{response.body.to_s.bytesize}"

        return unless response.status.success?

        self.class.parse_html(response)
      rescue StandardError
        # App.logger.error "[Genius] fetch_lyrics_html via proxy error: #{e.class} #{e.message}"
        nil
        # response = @http.get(url)
        # return unless response.status.success?

        # self.class.parse_html(response)
      end

      def self.parse_html(response)
        Nokogiri::HTML(response.to_s)
      end

      # call Genius /search
      # 回傳整個 parsed JSON (Hash)
      def search(query)
        res = @http.get("#{BASE}/search", params: { q: query })
        raise_api_error(res) unless res.status == 200

        json = JSON.parse(res.to_s)
        raise_api_error(res, 'Unauthorized Genius token') if json['error']&.match?(/invalid_token|unauthorized/i)
        json
      end

      private

      def raise_api_error(res, _msg = nil)
        raise HttpHelper::Response::ApiError.new(
          status_code: res.status
        )
      end
    end
  end
end
