# frozen_string_literal: true

require 'open3'
require 'json'

module LingoBeats
  module Mixins
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

        def run_python(words)
          command = ['python3', # '/Users/lyc/miniforge3/envs/lingobeats-nlp/bin/python',
                     'app/domain/songs/lib/cefrpy_service.py',
                     words.join(',')]
          Open3.capture3(*command)
        end
      end
    end
  end
end
