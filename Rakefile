# frozen_string_literal: true

require 'fileutils'
require 'rake/testtask'
require_relative 'require_app'

task :default do
  puts `rake -T`
end

desc 'Run unit and integration tests'
Rake::TestTask.new(:spec) do |t|
  puts 'Make sure worker is running in separate process'
  require_app
  t.pattern = 'spec/tests/**/*_spec.rb'
  t.warning = false
end

desc 'Keep rerunning unit/integration tests upon changes'
task :respec do
  sh "rerun -c 'rake spec' --ignore 'coverage/*' --ignore 'repostore/*'"
end

# session
desc 'Generates a 64 by secret for Rack::Session'
task :new_session_secret do
  require 'base64'
  require 'SecureRandom'
  secret = SecureRandom.random_bytes(64).then { Base64.urlsafe_encode64(it) }
  puts "SESSION_SECRET: #{secret}"
end

# run api
desc 'Run API (default: development mode)'
task run: ['run:dev']

namespace :run do
  desc 'Run API in dev mode'
  task :dev do
    sh 'bundle exec puma'
  end

  desc 'Run API in test mode'
  task :test do
    sh 'RACK_ENV=test bundle exec puma'
  end
end

desc 'Run API with auto-reloading (development mode)'
task :rerun do
  sh "rerun -c --ignore 'coverage/*' --ignore '_cache/*' -- bundle exec puma"
end

namespace :db do
  task :config do # rubocop:disable Rake/Desc
    require 'sequel'
    require_relative 'config/environment' # load config info
    require_relative 'spec/helpers/database_helper'

    def app # rubocop:disable Rake/MethodDefinitionInTask
      LingoBeats::App
    end
  end

  desc 'Run migrations'
  task :migrate => :config do
    Sequel.extension :migration
    puts "Migrating #{app.environment} database to latest"
    Sequel::Migrator.run(app.db, 'db/migrations')
  end

  desc 'Wipe records from all tables'
  task :wipe => :config do
    if app.environment == :production
      puts 'Do not damage production database!'
      return
    end

    DatabaseHelper.wipe_database
  end

  desc 'Delete database file based on DB_FILENAME env'
  task :drop do
    db_file = ENV['DB_FILENAME']
    abort 'DB_FILENAME env required for db:drop' unless db_file

    FileUtils.rm_f(db_file)
    FileUtils.rm_f("#{db_file}-wal")
    FileUtils.rm_f("#{db_file}-shm")
    puts "Deleted #{db_file}"
  end
end

# queue manipulation
namespace :queues do
  task :config do
    require 'aws-sdk-sqs'
    require_relative 'config/environment' # load config info
    @api = LingoBeats::App
    @sqs = Aws::SQS::Client.new(
      access_key_id: @api.config.AWS_ACCESS_KEY_ID,
      secret_access_key: @api.config.AWS_SECRET_ACCESS_KEY,
      region: @api.config.AWS_REGION
    )
    @q_name = @api.config.MATERIAL_QUEUE
    @q_url = @sqs.get_queue_url(queue_name: @q_name).queue_url

    puts "Environment: #{@api.environment}"
    puts "Queue URL: #{@q_url}"
  end

  # NOTE: Queue already created on AWS console. Do not run unless recreating queue.
  desc 'Create SQS queue for worker'
  task :create => :config do
    @sqs.create_queue(queue_name: @q_name)

    puts 'Queue created:'
    puts "  Name: #{@q_name}"
    puts "  Region: #{@api.config.AWS_REGION}"
    puts "  URL: #{@q_url}"
  rescue StandardError => e
    puts "Error creating queue: #{e}"
  end

  desc 'Report status of queue for worker'
  task :status => :config do
    puts 'Queue info:'
    puts "  Name: #{@q_name}"
    puts "  Region: #{@api.config.AWS_REGION}"
    puts "  URL: #{@q_url}"
  rescue StandardError => e
    puts "Error finding queue: #{e}"
  end

  desc 'Purge messages in SQS queue for worker'
  task :purge => :config do
    @sqs.purge_queue(queue_url: @q_url)
    puts "Queue #{@q_name} purged"
  rescue StandardError => e
    puts "Error purging queue: #{e}"
  end
end

namespace :worker do
  namespace :run do
    desc 'Run the background material generation worker in development mode'
    task :dev => 'queues:config' do
      sh 'RACK_ENV=development bundle exec shoryuken -r ./workers/material_generation_worker.rb -C ./workers/shoryuken_dev.yml'
    end

    desc 'Run the background material generation worker in testing mode'
    task :test => 'queues:config' do
      sh 'RACK_ENV=test bundle exec shoryuken -r ./workers/material_generation_worker.rb -C ./workers/shoryuken_test.yml'
    end

    desc 'Run the background material generation worker in production mode'
    task :production => 'queues:config' do
      sh 'RACK_ENV=production bundle exec shoryuken -r ./workers/material_generation_worker.rb -C ./workers/shoryuken.yml'
    end
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

desc 'Run application console'
task :console do
  sh 'pry -r ./load_all'
end

# manage vcr record file
namespace :vcr do
  desc 'delete cassette fixtures'
  task :wipe do
    files = Dir.glob('spec/fixtures/cassettes/**/*.yml')

    if files.any?
      FileUtils.rm(files)
      puts 'Cassettes deleted'
    else
      puts 'No cassettes found'
    end
  end
end
# namespace :vcr do
#   desc 'delete cassette fixtures'
#   task :wipe do
#     sh 'rm spec/fixtures/cassettes/**/*.yml' do |ok, _|
#       puts(ok ? 'Cassettes deleted' : 'No cassettes found')
#     end
#   end
# end

# check code quality
namespace :quality do
  only_app = 'config/ app/'

  desc 'run all static-analysis quality checks'
  task all: %i[rubocop reek flog]

  desc 'code style linter'
  task :rubocop do
    sh 'rubocop'
  end

  desc 'code smell detector'
  task :reek do
    sh "reek #{only_app}"
  end

  desc 'complexiy analysis'
  task :flog do
    sh "flog -m #{only_app}"
  end
end
