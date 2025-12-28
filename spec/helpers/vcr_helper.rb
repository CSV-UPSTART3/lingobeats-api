# frozen_string_literal: true

require 'vcr'
require 'webmock'

# Setting up VCR
module VcrHelper
  CASSETTES_FOLDER = 'spec/fixtures/cassettes'
  CASSETTE_FILE = 'spotify_api' # store title for vcr

  def self.setup_vcr
    VCR.configure do |c|
      c.cassette_library_dir = CASSETTES_FOLDER
      c.hook_into :webmock
      c.ignore_hosts 'sqs.us-east-1.amazonaws.com'
      c.ignore_hosts 'sqs.ap-northeast-1.amazonaws.com'
    end
  end

  def self.configure_vcr_for_spotify
    VCR.configure do |c|
      configure_sensitive_data(c)
      configure_request_filter(c)
      configure_response_filter(c)
    end

    insert_spotify_cassette
  end

  def self.configure_sensitive_data(config)
    encoded_auth = spotify_basic_auth

    config.filter_sensitive_data('<SPOTIFY_CLIENT_ID>') { SPOTIFY_CLIENT_ID }
    config.filter_sensitive_data('<SPOTIFY_CLIENT_SECRET>') { SPOTIFY_CLIENT_SECRET }
    config.filter_sensitive_data('<SPOTIFY_BASIC_AUTH>') { encoded_auth }
    config.filter_sensitive_data('<SPOTIFY_BASIC_AUTH_ESC>') { CGI.escape(encoded_auth) }
  end

  def self.spotify_basic_auth
    Base64.strict_encode64("#{SPOTIFY_CLIENT_ID}:#{SPOTIFY_CLIENT_SECRET}")
  end

  def self.configure_request_filter(config)
    config.before_record do |interaction|
      mask_bearer_token!(interaction)
      mask_access_token_in_body!(interaction)
    end
  end

  def self.mask_bearer_token!(interaction)
    auth = interaction.request.headers['Authorization']&.first
    return unless auth&.start_with?('Bearer ')

    interaction.request.headers['Authorization'] = ['Bearer <SPOTIFY_ACCESS_TOKEN>']
  end

  def self.mask_access_token_in_body!(interaction)
    body = parse_json(interaction.response.body)
    return unless body&.key?('access_token')

    body['access_token'] = '<SPOTIFY_ACCESS_TOKEN>'
    interaction.response.body = JSON.generate(body)
  end

  def self.configure_response_filter(config)
    config.before_record do |interaction|
      body = parse_json(interaction.response.body)
      next unless body&.key?('access_token')

      body['access_token'] = '<SPOTIFY_ACCESS_TOKEN>'
      interaction.response.body = JSON.generate(body)
    end
  end

  def self.parse_json(raw)
    JSON.parse(raw)
  rescue JSON::ParserError
    nil
  end

  def self.insert_spotify_cassette
    VCR.insert_cassette(CASSETTE_FILE, record: :new_episodes, match_requests_on: %i[method uri headers])
  end

  # ----------------- Genius -----------------
  CASSETTE_FILE_GENIUS = 'genius_api'

  def self.configure_vcr_for_genius
    VCR.configure do |c|
      configure_genius_sensitive_data(c)
      configure_genius_request_filter(c)
    end

    insert_genius_cassette
  end

  def self.configure_genius_sensitive_data(config)
    config.filter_sensitive_data('<GENIUS_CLIENT_ACCESS_TOKEN>') do
      GENIUS_CLIENT_ACCESS_TOKEN if defined?(GENIUS_CLIENT_ACCESS_TOKEN)
    end
  end

  def self.configure_genius_request_filter(config)
    config.before_record do |interaction|
      mask_genius_bearer_token!(interaction)
    end
  end

  def self.mask_genius_bearer_token!(interaction)
    auth = interaction.request.headers['Authorization']&.first
    return unless auth&.start_with?('Bearer ')

    interaction.request.headers['Authorization'] =
      ['Bearer <GENIUS_CLIENT_ACCESS_TOKEN>']
  end

  def self.insert_genius_cassette
    VCR.insert_cassette(CASSETTE_FILE_GENIUS, record: :new_episodes, match_requests_on: %i[method uri headers])
  end

  # ----------------- Gemini -----------------
  CASSETTE_FILE_GEMINI = 'gemini_api'
  def self.configure_vcr_for_gemini
    VCR.configure do |c|
      c.filter_sensitive_data('<GEMINI_API_KEY>') { ENV.fetch('GEMINI_API_KEY', nil) }
      c.cassette_library_dir = 'spec/fixtures/cassettes'
      c.hook_into :webmock
    end

    VCR.insert_cassette(CASSETTE_FILE_GEMINI, record: :new_episodes, match_requests_on: %i[method uri headers])
  end

  def self.eject_vcr
    VCR.eject_cassette
  end
end
