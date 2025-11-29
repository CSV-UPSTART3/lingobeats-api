# frozen_string_literal: true

ENV['RACK_ENV'] = 'test'

require 'simplecov'
# Test coverage
SimpleCov.start do
  add_filter '/spotify/gateways/http_helper.rb'
end

require 'yaml'

# VCR and WebMock setup for testing external API calls
require 'minitest/autorun'
require 'minitest/unit'
require 'minitest/rg'
require 'vcr'
require 'webmock'

require_relative '../../require_app'
require_app

require_relative 'vcr_helper'
VcrHelper.setup_vcr

SINGER = 'Ed Sheeran'
SONG_NAME = 'Golden'
SONG_ID = '0bHs3ly4Bv5BlzE3KrePfX'
CONFIG = YAML.safe_load_file('config/secrets.yml')
SPOTIFY_CLIENT_ID = CONFIG['development']['SPOTIFY_CLIENT_ID']
SPOTIFY_CLIENT_SECRET = CONFIG['development']['SPOTIFY_CLIENT_SECRET']
GENIUS_CLIENT_ACCESS_TOKEN = CONFIG['development']['GENIUS_CLIENT_ACCESS_TOKEN']
GEMINI_API_KEY = CONFIG['development']['GEMINI_API_KEY']
CORRECT_RESULT_BY_SINGER = YAML.safe_load_file('spec/fixtures/spotify_result_by_singer.yml',
                                               permitted_classes: [Symbol])
CORRECT_RESULT_BY_SONG = YAML.safe_load_file('spec/fixtures/spotify_result_by_song_name.yml',
                                             permitted_classes: [Symbol])
CORRECT_RESULT_BY_BILLBOARD = YAML.safe_load_file('spec/fixtures/billboard_result.yml',
                                                  permitted_classes: [Symbol])
CORRECT_RESULT_BY_LYRICS = File.read('spec/fixtures/lyrics_output.txt')
