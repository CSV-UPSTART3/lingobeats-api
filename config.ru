# frozen_string_literal: true

require 'faye'
require 'rack/cors'

require_relative 'require_app'

require_app

use Rack::Cors do
  allow do
    origins '*'
    resource '*',
             headers: :any,
             methods: %i[get post put patch delete options head]
  end
end

use Faye::RackAdapter, mount: '/faye', timeout: 25
run LingoBeats::App.freeze.app
