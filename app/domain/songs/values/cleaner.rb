# frozen_string_literal: true

module LingoBeats
  module Value
    # Text cleaner for song lyrics
    class Cleaner
      def initialize(raw_text)
        @raw_text = raw_text
      end

      def call
        return '' if @raw_text.to_s.strip.empty?

        @raw_text = @raw_text.gsub(/[\[{].*?[\]}]/, '') # 移除中括號、圓括號、花括號內容
        @raw_text.gsub!(/\n{2,}/, "\n\n") # 移除連續空行
        @raw_text.strip
        # @raw_text = @raw_text.gsub(/[^a-zA-Z\s'-]/, ' ') # 移除非英文與符號（保留空白、撇號）
        # @raw_text.strip.gsub(/\s+/, ' ') # 清除多餘空白
      end
    end
  end
end
