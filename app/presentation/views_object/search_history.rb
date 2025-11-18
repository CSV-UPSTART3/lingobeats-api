# frozen_string_literal: true

module Views
  # View for a single search history entity
  class SearchHistory
    def initialize(history)
      @history = history
    end

    def for(category)
      category.to_s == 'singer' ? @history.singers : @history.song_names
    end
  end
end
