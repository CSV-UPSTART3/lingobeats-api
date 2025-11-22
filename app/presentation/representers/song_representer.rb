# frozen_string_literal: true

require 'roar/decorator'
require 'roar/json'

require_relative 'singer_representer'

# Represents essential Song information for API output
module LingoBeats
  module Representer
    # Represent a Song entity as Json
    class Song < Roar::Decorator
      include Roar::JSON
      include Roar::Hypermedia
      include Roar::Decorator::HypermediaConsumer

      property :id
      property :name
      property :uri
      property :external_url
      property :album_id
      property :album_name
      property :album_url
      property :album_image_url
      collection :singers, extend: Representer::Singer, class: OpenStruct
      # property :lyric, extend: Representer::Lyric, class: OpenStruct

      # link :self do
      #   "#{App.config.API_HOST}/api/v1/songs/#{song_id}"
      # end

      private

      def song_id
        represented.id
      end
    end
  end
end
