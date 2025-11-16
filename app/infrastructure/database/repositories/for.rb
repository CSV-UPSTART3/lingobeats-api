# frozen_string_literal: true

require_relative 'vocabularies'
require_relative 'singers'
require_relative 'songs'
require_relative 'lyrics'

module LingoBeats
  module Repository
    # Finds the right repository for an entity object or class
    module For
      ENTITY_REPOSITORY = {
        Entity::Singer => Singers,
        Entity::Song => Songs,
        Entity::Vocabulary => Vocabularies,
        Value::Lyric => Lyrics
      }.freeze

      def self.klass(entity_klass)
        ENTITY_REPOSITORY[entity_klass]
      end

      def self.entity(entity_object)
        ENTITY_REPOSITORY[entity_object.class]
      end
    end
  end
end
