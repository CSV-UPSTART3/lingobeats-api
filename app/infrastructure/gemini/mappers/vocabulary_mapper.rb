# frozen_string_literal: false

require 'json'

module LingoBeats
  module Gemini
    # Data Mapper: Gemini API <-> Vocabulary entity
    class VocabularyMapper
      attr_reader :gateway

      def initialize(access_token:, gateway_class: LingoBeats::Gemini::Api)
        @gateway = gateway_class.new(
          token_provider: StaticTokenProvider.new(access_token)
        )
      end

      # provide static token for Gemini API
      class StaticTokenProvider
        attr_reader :api_key

        def initialize(api_key) = @api_key = api_key
      end

      # Gemini payload → material_hash
      module MaterialParser
        module_function

        def extract_text(payload)
          parts = payload.dig('candidates', 0, 'content', 'parts')
          return nil unless parts.is_a?(Array) && !parts.empty?

          parts.map { |part| part['text'] }.compact.join("\n")
        end

        def strip_code_fences(text)
          return '' if text.nil?

          text
            .sub(/\A```json\s*/i, '') # starts with ```json
            .sub(/\A```/, '')         # or only ```
            .sub(/```$/, '')          # end ```
            .strip
        end

        # remove extra: `, ]` / `, }`
        def relax_trailing_commas(text)
          text.gsub(/,\s*([\]}])/, '\1')
        end

        def symbolize_keys(obj)
          case obj
          when Hash
            obj.each_with_object({}) do |(k, v), h|
              h[k.to_sym] = symbolize_keys(v)
            end
          when Array
            obj.map { |v| symbolize_keys(v) }
          else
            obj
          end
        end

        # ----- single mode: original parse_material / build_from_payload -----

        def parse_payload(payload)
          text = extract_text(payload)
          return nil if text.to_s.strip.empty?

          cleaned = relax_trailing_commas(strip_code_fences(text))
          raw = JSON.parse(cleaned)

          symbolize_keys(raw)
        rescue JSON::ParserError
          { raw_text: text }
        end

        # ----- batch mode: for AddMaterial -----

        def parse_batch(payload)
          text = strip_code_fences(extract_text(payload).to_s).strip
          return [] if text.empty?

          cleaned = relax_trailing_commas(text)
          raw     = begin
            JSON.parse(cleaned)
          rescue StandardError
            { raw_text: text }
          end
          array = raw.is_a?(Array) ? raw : [raw]

          symbolize_keys(array)
        end
      end

      # For Service：batch processing vocabulary materials
      def generate_and_parse(prompt)
        payload = @gateway.generate_content(prompt)
        MaterialParser.parse_batch(payload)
      end

      # material_hash + 其他欄位 → Vocabulary entity
      class DataMapper
        def initialize(material_hash, name:, level:)
          @material = material_hash
          @name     = name
          @level    = level
        end

        def build_entity
          LingoBeats::Entity::Vocabulary.new(
            id: nil,
            name: @name,
            level: @level,
            material: @material # Hash, NOT JSON string (Repo 會負責轉 JSON)
          )
        end
      end

      # dict：payload → material_hash
      def self.parse_material(payload)
        MaterialParser.parse_payload(payload)
      end

      # 直接拿 Vocabulary：payload → Vocabulary entity
      def self.build_from_payload(payload, name:, level:)
        material_hash = MaterialParser.parse_payload(payload)
        DataMapper.new(material_hash, name:, level:).build_entity
      end
    end
  end
end
