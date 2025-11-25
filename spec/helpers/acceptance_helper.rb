# frozen_string_literal: true

# load helpers in 'test' environment first
require_relative 'spec_helper'
require_relative 'database_helper'
require_relative 'vcr_helper'

# revert to app_test environment as DB no longer needed
ENV['RACK_ENV'] = 'app_test'

# require 'headless'
require 'watir'
require 'page-object'
