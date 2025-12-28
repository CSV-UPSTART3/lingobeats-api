# frozen_string_literal: true

require 'open3'
require 'json'

module LingoBeats
  module Songs
    module Services
      # Difficulty estimator using external Python script
      class DifficultyEstimator
        def initialize(words)
          @words = words
        end

        def call
          return {} if @words.empty?

          stdout, stderr, status = PythonRunner.run_python(@words)
          return JSON.parse(stdout) if status.success?

          warn "Python failed (#{status.exitstatus}): #{stderr}"
          {}
        end

        # Run the Python script to evaluate word difficulties
        module PythonRunner
          module_function

          SCRIPT_PATH = 'app/domain/songs/python/cefrpy_service.py'

          def run_python(words)
            command = [App.config.PYTHON_PATH || 'python3',
                       SCRIPT_PATH,
                       words.join(',')]
            Open3.capture3(*command)
          end
        end
      end
    end
  end
end
