# app/infrastructure/gemini/mappers/vocabulary_mapper.rb
module LingoBeats
  module Gemini
    # 建立 Vocabulary 的 mapper
    class VocabularyMapper
      attr_reader :gateway

      def initialize(access_token:, gateway_class: LingoBeats::Gemini::Api)
        @gateway = gateway_class.new(
          token_provider: StaticTokenProvider.new(access_token)
        )
      end

      class StaticTokenProvider
        attr_reader :api_key

        def initialize(api_key) = @api_key = api_key
      end

      # Gemini payload → material_hash
      module MaterialParser
        module_function

        def parse_payload(payload)
          text = extract_text(payload)
          return nil if text.to_s.strip.empty?

          raw =
            begin
              JSON.parse(text)
            rescue JSON::ParserError
              { 'raw_text' => text }
            end

          symbolize_keys(raw)
        end

        # 從 candidates.parts 抽文字
        def extract_text(payload)
          parts = payload.dig('candidates', 0, 'content', 'parts')
          return nil unless parts.is_a?(Array) && !parts.empty?

          parts.map { |part| part['text'] }.compact.join("\n")
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

        def strip_code_fences(text)
          text
            .sub(/\A```json\s*/i, '')  # 開頭的 ```json
            .sub(/```$/, '')           # 結尾的 ```
            .strip
        end

        def parse_batch(payload)
          text = extract_text(payload)
          return [] if text.to_s.strip.empty?

          cleaned = strip_code_fences(text)

          raw_array = JSON.parse(cleaned)
          symbolize_keys(raw_array)
        rescue JSON::ParserError
          [{ raw_text: text }]
        end
        module_function :parse_batch
      end

      # For Service
      def generate_and_parse(prompt)
        payload = @gateway.generate_content(prompt)
        MaterialParser.parse_batch(payload)
      end

      # material_hash + 其他欄位 → Vocabulary entity
      class DataMapper
        def initialize(material_hash, song_id:, name:, level:)
          @material = material_hash
          @song_id  = song_id
          @name     = name
          @level    = level
        end

        def build_entity
          LingoBeats::Entity::Vocabulary.new(
            song_id: @song_id,
            name: @name,
            level: @level,
            material: @material
          )
        end
      end

      # dict：payload → material_hash
      def self.parse_material(payload)
        MaterialParser.parse_payload(payload)
      end

      # 直接拿 Vocabulary：payload → Vocabulary entity
      def self.build_from_payload(payload, song_id:, name:, level:)
        material_hash = MaterialParser.parse_payload(payload)
        DataMapper.new(material_hash, song_id:, name:, level:).build_entity
      end
    end
  end
end
