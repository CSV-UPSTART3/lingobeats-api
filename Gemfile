# frozen_string_literal: true

source 'https://rubygems.org'
ruby File.read('.ruby-version').strip

# Configuration and Utilities
gem 'cld3'
gem 'figaro', '~> 1.0'
gem 'pry'
gem 'pycall'
gem 'rake'

# Web Application
gem 'base64'
gem 'logger', '~> 1.0'
gem 'puma', '~> 7.0'
gem 'rack-cors'
gem 'rack-session', '~> 0'
gem 'roda', '~> 3.0'
gem 'slim', '~> 4.0'

# Networking
gem 'http', '~> 5.0'
gem 'rack', '~> 3.2'

# Testing
group :test do
  gem 'minitest', '~> 5.20'
  gem 'minitest-rg', '~> 5.2'
  gem 'simplecov', '~> 0'
  gem 'vcr', '~> 6'
  gem 'webmock', '~> 3'

  gem 'headless', '~> 2.3'
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

# HTML Parsing
gem 'nokogiri'

# Data Validation
gem 'dry-struct', '~> 1.8'
gem 'dry-types', '~> 1.8'

# Database
gem 'hirb'
gem 'sequel', '~> 5.0'

group :development, :test do
  gem 'sqlite3', '~> 1.0'
end

group :production do
  gem 'pg'
end
