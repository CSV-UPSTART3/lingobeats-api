# frozen_string_literal: true

require 'dry/transaction'

module LingoBeats
  module Service
    # Transaction to generate and add material for vocabularies of a song
    class AddMaterial
      include Dry::Transaction

      # TODO: add steps

      # helper: prompt loader
      class PromptLoader
        def self.render(template_name, locals = {})
          path = File.join('app/application/services/prompts', template_name)
          template = File.read(path)
          ERB.new(template).result_with_hash(locals)
        end
      end
    end
  end
end
