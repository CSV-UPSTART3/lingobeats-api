# frozen_string_literal: true

module LingoBeats
  module Repository
    # Repository for SearchHistories (session-based)
    class SearchHistories
      SONG_KEY   = :song_search_history
      SINGER_KEY = :singer_search_history

      def initialize(session)
        @session = session
      end

      def load
        Entity::SearchHistory.new(
          song_names: Array(@session[SONG_KEY]),
          singers: Array(@session[SINGER_KEY])
        )
      end

      def store(entity)
        payload = entity.to_h
        @session[SONG_KEY] = payload[:song_search_history]
        @session[SINGER_KEY] = payload[:singer_search_history]
        entity
      end

      def add_record(category:, query:)
        entity = load
        updated = entity.add(category:, query:)
        store(updated)
      end

      def remove_record(category:, query:)
        entity = load
        updated = entity.remove(category:, query:)
        store(updated)
      end
    end
  end
end
