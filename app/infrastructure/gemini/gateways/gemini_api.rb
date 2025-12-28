# frozen_string_literal: true

require 'json'
require 'http'

module LingoBeats
  module Gemini
    # 組 URL → 發 HTTP POST → 回 Ruby Hash
    class Api
      BASE  = 'https://generativelanguage.googleapis.com/v1beta/models'
      MODEL = 'gemini-2.0-flash'

      # 專門用來檢查 HTTP 回應是否成功，失敗就 raise，成功回傳 body
      ENSURE_SUCCESS = lambda do |status, body|
        raise "Gemini HTTP #{status}: #{body}" unless status == 200

        body
      end

      def initialize(token_provider:, model: MODEL, http_client: HTTP)
        @token_provider = token_provider
        @model          = model
        @http           = http_client
        @user_role      = 'user'
      end

      # prompt: String or Array<String>
      def generate_content(prompt)
        Functionality.validate_prompt!(prompt)

        response = @http.post(request_url, json: request_body(prompt))
        status = response.status.to_i
        body = response.to_s
        body = ENSURE_SUCCESS.call(status, body)

        JSON.parse(body)
      end

      private

      def request_url
        "#{BASE}/#{@model}:generateContent?key=#{@token_provider.api_key}"
      end

      def request_body(prompt)
        {
          contents: [
            {
              role: @user_role,
              parts: Functionality.build_parts(prompt)
            }
          ]
        }
      end

      # Functionality module for Gemini API
      module Functionality
        module_function

        def validate_prompt?(prompt)
          case prompt
          when String
            nonblank_string?(prompt)
          when Array
            nonblank_array?(prompt)
          else
            false
          end
        end

        def validate_prompt!(prompt)
          raise ArgumentError, 'prompt required' unless validate_prompt?(prompt)
        end

        def build_parts(prompt)
          arr = prompt.is_a?(Array) ? prompt : [prompt]
          arr.map { |text| { text: text.to_s } }
        end

        def nonblank_string?(prompt)
          prompt.is_a?(String) && !prompt.strip.empty?
        end

        def nonblank_array?(prompt)
          return false if prompt.empty?

          prompt.all? { |text| nonblank_string?(text) }
        end
      end
    end
  end
end
