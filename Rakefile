# frozen_string_literal: true

require 'rake/testtask'
require 'fileutils'
require_relative 'require_app'
require 'bundler/setup'
# Bundler.require(:default)

task :default do
  puts `rake -T`
end

# run all test
desc 'Run tests once'
Rake::TestTask.new(:spec) do |t|
  t.libs << 'lib' << 'spec'
  t.pattern = 'spec/**/*_spec.rb'
  # t.pattern = 'spec/spotify_api_spec.rb'
  # t.pattern = 'spec/gateway_database_spec.rb'
  t.warning = false
end

desc 'Keep rerunning tests upon changes'
task :respec do
  sh "rerun -c 'rake spec' --ignore 'coverage/*'"
end

desc 'Run application console (irb)'
task :console do
  sh 'pry -r ./load_all'
end

# manage vcr record file
namespace :vcr do
  desc 'delete cassette fixtures (*.yml)'
  task :wipe do
    files = Dir['spec/fixtures/cassettes/*.yml']
    if files.empty?
      puts 'No cassettes found'
    else
      FileUtils.rm_f(files)
      puts "Cassettes deleted: #{files.size}"
    end
  end
end

# check code quality
namespace :quality do
  desc 'run all quality checks'
  task all: %i[rubocop reek flog]

  desc 'Run RuboCop'
  task :rubocop do
    puts '[RuboCop]'
    sh 'bundle', 'exec', 'rubocop', *CODE_DIRS do
      puts # avoid aborting
    end
  end

  desc 'Run Reek'
  task :reek do
    puts '[Reek]'
    sh 'bundle', 'exec', 'reek', *CODE_DIRS do
      puts # avoid aborting
    end
  end

  desc 'Run Flog'
  task :flog do
    puts '[Flog]'
    sh 'bundle', 'exec', 'flog', *CODE_DIRS
  end
end

# run application
namespace :app do
  desc 'Run web app'
  task :run do
    sh 'bundle exec puma'
  end

  desc 'Keep rerunning web app upon changes'
  task :rerun do
    sh "rerun -c --ignore 'coverage/*' -- bundle exec puma"
  end
end

# session
desc 'Generates a 64 by secret for Rack::Session'
task :new_session_secret do
  require 'base64'
  require 'securerandom'
  secret = SecureRandom.random_bytes(64).then { Base64.urlsafe_encode64(it) }
  puts "SESSION_SECRET: #{secret}"
end

# db manipulation
namespace :db do
  task :config do
    require 'sequel'
    require_relative 'config/environment' # load config info
    require_relative 'spec/helpers/database_helper'

    def app = LingoBeats::App
  end

  desc 'Run migrations'
  task migrate: :config do
    Sequel.extension :migration
    puts "Migrating #{app.environment} database to latest"
    Sequel::Migrator.run(app.db, 'db/migrations')
  end

  desc 'Wipe records from all tables'
  task wipe: :config do
    if app.environment == :production
      puts 'Do not damage production database!'
      return
    end

    require_app
    DatabaseHelper.wipe_database
  end

  desc 'Delete dev or test database file (set correct RACK_ENV)'
  task drop: :config do
    if app.environment == :production
      puts 'Do not damage production database!'
      return
    end

    FileUtils.rm(LingoBeats::App.config.DB_FILENAME)
    puts "Deleted #{LingoBeats::App.config.DB_FILENAME}"
  end
end

# cache manipulation
namespace :cache do
  task :config do # rubocop:disable Rake/Desc
    require_relative 'app/infrastructure/cache/local_cache'
    require_relative 'app/infrastructure/cache/redis_cache'
    require_relative 'config/environment' # load config info
    @api = LingoBeats::App
  end

  desc 'Directory listing of local dev cache'
  namespace :list do
    desc 'Lists development cache'
    task :dev => :config do
      puts 'Lists development cache'
      keys = LingoBeats::Cache::Local.new(@api.config).keys
      puts 'No local cache found' if keys.none?
      keys.each { |key| puts "Key: #{key}" }
    end

    desc 'Lists production cache'
    task :production => :config do
      puts 'Finding production cache'
      keys = LingoBeats::Cache::Remote.new(@api.config).keys
      puts 'No keys found' if keys.none?
      keys.each { |key| puts "Key: #{key}" }
    end
  end

  namespace :wipe do
    desc 'Delete development cache'
    task :dev => :config do
      puts 'Deleting development cache'
      LingoBeats::Cache::Local.new(@api.config).wipe
      puts 'Development cache wiped'
    end

    desc 'Delete production cache'
    task :production => :config do
      print 'Are you sure you wish to wipe the production cache? (y/n) '
      if $stdin.gets.chomp.downcase == 'y'
        puts 'Deleting production cache'
        wiped = LingoBeats::Cache::Remote.new(@api.config).wipe
        wiped.each { |key| puts "Wiped: #{key}" }
      end
    end
  end
end
