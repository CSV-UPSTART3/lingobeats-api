# frozen_string_literal: true

require_relative 'helpers/spec_helper'
require_relative 'helpers/vcr_helper'
require_relative 'helpers/yaml_helper'

describe 'Tests Genius API library' do
  before do
    VcrHelper.setup_vcr
    VcrHelper.configure_vcr_for_genius
  end

  after do
    VcrHelper.eject_vcr
  end

  describe 'Lyrics content check' do
    it 'HAPPY: should fetch correct lyrics text' do
      genius_mapper = LingoBeats::Genius::LyricMapper.new(GENIUS_CLIENT_ACCESS_TOKEN)
      lyrics = genius_mapper.lyrics_for(song_name: 'Golden', singer_name: 'HUNTR/X')

      _(lyrics).wont_be_nil
      _(lyrics.text).must_be_kind_of(String)
      _(lyrics.text.strip.empty?).must_equal false
    end

    it 'SAD: should return nil when song does not exist' do
      genius_mapper = LingoBeats::Genius::LyricMapper.new(GENIUS_CLIENT_ACCESS_TOKEN)
      result = genius_mapper.lyrics_for(song_name: 'totally-not-exist-zzz', singer_name: 'totally-not-exist-zzz')
      _(result).must_be_nil
    end

    it 'SAD: raises ArgumentError when missing keyword arguments' do
      _(proc do
        LingoBeats::Genius::LyricMapper.new(GENIUS_CLIENT_ACCESS_TOKEN)
                                      .lyrics_for('Photograph', 'Ed Sheeran')
      end).must_raise ArgumentError
    end

    it 'SAD: raises ApiError when unauthorized token used' do
      _(proc do
        LingoBeats::Genius::LyricMapper.new('BAD_TOKEN')
                                      .lyrics_for(song_name: 'Photograph', singer_name: 'Ed Sheeran')
      end).must_raise LingoBeats::HttpHelper::Response::ApiError
    end
  end
end
