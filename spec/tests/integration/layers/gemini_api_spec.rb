# frozen_string_literal: true

require_relative '../../../helpers/spec_helper'
require_relative '../../../helpers/vcr_helper'
require_relative '../../../helpers/yaml_helper'

ENV['GEMINI_API_KEY'] ||= GEMINI_API_KEY if defined?(GEMINI_API_KEY)

describe 'Tests Gemini API → Vocabulary pipeline' do
  before do
    VcrHelper.setup_vcr
    VcrHelper.configure_vcr_for_gemini
  end

  after do
    VcrHelper.eject_vcr
  end

  describe LingoBeats::Gemini::VocabularyMapper do
    it 'HAPPY: parses Gemini batch response into vocabulary materials' do
      payload = {
        'candidates' => [
          {
            'content' => {
              'parts' => [
                {
                  'text' => <<~TEXT
                    ```json
                    [
                    {
                        "word": "ghost",
                        "cefr": "A1",
                        "entries": [
                        { "meaning": "a dead person’s spirit", "example": "I saw a ghost." }
                        ]
                    },
                    {
                        "word": "queen",
                        "cefr": "A2",
                        "entries": [
                        { "meaning": "female ruler", "example": "She is the queen." }
                        ]
                    }
                    ]
                    ```
                  TEXT
                }
              ]
            }
          }
        ]
      }
      result = LingoBeats::Gemini::VocabularyMapper::MaterialParser.parse_batch(payload)

      # 型別檢查
      _(result).must_be_kind_of Array
      _(result).wont_be_empty

      first = result.first
      _(first).must_be_kind_of Hash
      _(first).must_include :word
      _(first).must_include :entries
      _(first[:entries]).must_be_kind_of Array
    end

    describe 'SAD: handles invalid / empty response' do
      it 'returns empty array when model output is empty/invalid' do
        bad_payload = {
          'candidates' => [
            { 'content' => { 'parts' => [] } }
          ]
        }

        result = LingoBeats::Gemini::VocabularyMapper::MaterialParser.parse_batch(bad_payload)

        _(result).must_be_kind_of Array
        _(result).must_be_empty
      end
    end
  end

  describe 'Live Gemini API call (recorded via VCR)' do
    it 'requests vocabulary materials for actual prompt' do
      mapper = LingoBeats::Gemini::VocabularyMapper.new(access_token: GEMINI_API_KEY)
      prompt = <<~PROMPT
        Generate JSON array describing vocabulary materials.
        For each item include: "word", "cefr", and "entries" (each entry with "meaning" and "example").
        Words:
        - "serendipity" (level C1)
        - "resilient" (level B2)
        Respond with strict JSON only.
      PROMPT

      result = mapper.generate_and_parse(prompt)

      _(result).must_be_kind_of Array
      _(result).wont_be_empty

      first = result.first
      _(first).must_include :word
      _(first).must_include :entries
      _(first[:entries]).must_be_kind_of Array
    end
  end
end
