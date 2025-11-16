# frozen_string_literal: true

require 'nokogiri'

module LingoBeats
  module Genius
    # Maps Genius API lyric data into domain entities.
    class LyricMapper
      def initialize(access_token, gateway_class = LingoBeats::Genius::Api)
        @gateway_class = gateway_class
        @gateway = @gateway_class.new(
          token_provider: StaticTokenProvider.new(access_token)
        )
      end

      # 小幫手類別：符合 Genius::Api 期待的介面
      class StaticTokenProvider
        def initialize(token)
          @token = token
        end

        def access_token
          @token
        end
      end

      # 給歌名/歌手名字，回傳乾淨歌詞字串，或 nil
      def lyrics_for(song_name:, singer_name:)
        lyrics_page_url = first_lyrics_url(self.class.build_query(song_name, singer_name))
        return nil unless lyrics_page_url

        html_doc = @gateway.fetch_lyrics_html(lyrics_page_url)
        # App.logger.info html_doc
        return nil unless html_doc

        lyrics_text = LyricsExtractor.extract_lyrics_text(html_doc)
        return nil unless lyrics_text

        Value::Lyric.new(text: lyrics_text)
      end

      def self.build_query(song_name, singer_name)
        if singer_name && !singer_name.strip.empty?
          "#{song_name} #{singer_name}"
        else
          song_name.to_s
        end
      end

      # 從 Genius /search JSON 拿到第一筆歌曲的網頁 url
      def first_lyrics_url(query)
        json = @gateway.search(query)
        hits = json.dig('response', 'hits') || []
        first_hit = hits.first
        return nil unless first_hit

        first_hit.dig('result', 'url')
      end

      # Extract lyric from html document
      module LyricsExtractor
        module_function

        # 把 HTML 轉成「整齊歌詞字串」
        def extract_lyrics_text(html_doc)
          return nil unless html_doc

          blocks = find_lyric_blocks(html_doc)
          return nil if blocks.empty?

          text_only = strip_tags_with_br(blocks)
          refine_lyrics(text_only)
        end

        def find_lyric_blocks(html_doc)
          html_doc.css('div[class^="Lyrics__Container"]')
        end

        def strip_tags_with_br(blocks)
          raw_html = blocks.map { |div| div.inner_html.gsub('<br>', "\n") }.join("\n")
          Nokogiri::HTML(raw_html).text
        end

        def refine_lyrics(text)
          text = text.sub(/\A.*?(?=\[[^\]]+\])/m, '')
          lyrics_start_idx = text.index(/\[[A-Za-z0-9\s#]+\]/)
          core = lyrics_start_idx ? text[lyrics_start_idx..] : text
          core.gsub(/\s*\[([^\]]+)\]\s*/, "\n\n[\\1]\n")
              .gsub(/([a-z)])(\[)/, "\\1\n\\2")
              .strip
        end
      end
    end
  end
end
