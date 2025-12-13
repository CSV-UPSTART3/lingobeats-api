# frozen_string_literal: true

module MaterialGeneration
  module GenerationMonitor
    def self.starting
      { status: 'started', percent: 5 }
    end

    def self.progress(current, total)
      percent = (current.to_f / total * 90).round + 5
      {
        status: 'generating',
        current: current,
        total: total,
        percent: percent
      }
    end

    def self.finished
      { status: 'finished', percent: 100 }
    end
  end
end
