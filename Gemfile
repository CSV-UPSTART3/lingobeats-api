# frozen_string_literal: true

source 'https://rubygems.org'
ruby File.read('.ruby-version').strip

# Configuration and Utilities
gem 'cld3'
gem 'figaro', '~> 1.0'
gem 'pry'
gem 'pycall'
gem 'rake'

# PRESENTATION LAYER
gem 'slim', '~> 4.0'

# APPLICATION LAYER
# Web Application related
gem 'base64'
gem 'logger', '~> 1.0'
gem 'puma', '~> 7.0'
gem 'rack', '~> 3.2'
gem 'rack-cors'
gem 'rack-session', '~> 0'
gem 'roda', '~> 3.0'

# Controllers and services
gem 'dry-monads', '~> 1.0'
gem 'dry-transaction', '~> 0'
gem 'dry-validation', '~> 1.0'

# HTML Parsing
gem 'nokogiri'

# DOMAIN LAYER
# Validation
gem 'dry-struct', '~> 1.0'
gem 'dry-types', '~> 1.0'

# INFRASTRUCTURE LAYER
# Networking
gem 'http', '~> 5.0'

# Database
gem 'hirb'
gem 'sequel', '~> 5.0'

group :development, :test do
  gem 'sqlite3', '~> 1.0'
end

group :production do
  gem 'pg'
end

# TESTING
group :test do
  # Unit/Integration/Acceptance Tests
  gem 'minitest', '~> 5.20'
  gem 'minitest-rg', '~> 5.2'
  gem 'simplecov', '~> 0'
  gem 'vcr', '~> 6'
  gem 'webmock', '~> 3'

  # Acceptance Tests
  gem 'headless', '~> 2.3'
  gem 'page-object', '~> 2.0'
  gem 'selenium-webdriver', '~> 4.11'
  gem 'watir', '~> 7.0'
end

# Development
group :development do
  gem 'flog'
  gem 'reek'
  gem 'rerun'
  gem 'rubocop'
  gem 'rubocop-minitest'
  gem 'rubocop-rake'
  gem 'rubocop-sequel'
end
