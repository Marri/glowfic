source 'https://rubygems.org'

ruby '2.6.3'

gem 'api-pagination'
gem 'apipie-rails'
gem 'audited', '~> 4.9.0' # check for migrations after update with `rails generate audited:upgrade`
gem 'aws-sdk-rails', '~> 2'
gem 'aws-sdk-s3', '~> 1'
gem 'aws-sdk-ses', '~> 1'
gem 'bootstrap'
gem 'coffee-rails'
gem 'exception_notification'
gem 'gon'
gem 'haml-rails'
gem 'httparty'
gem 'jquery-rails', '>= 4.3.4'
gem 'jquery-ui-rails'
gem 'newrelic_rpm'
gem 'nilify_blanks'
gem 'nokogiri'
gem 'pg', '~> 0.21.0'
gem 'pg_search'
gem 'rack-pratchett'
gem 'rails', '~> 5.2.0'
gem 'redis', '~> 3.3.5' # until resque updates to support Redis 4
gem 'redis-rails'
gem 'resque'
gem 'resque-scheduler'
gem 'resque-web', '0.0.12', require: 'resque_web'
gem 'resque_mailer'
gem 'sanitize'
gem 'sassc-rails'
gem 'select2-rails'
gem 'test-unit', '~> 3.0' # required by Heroku for production console
gem 'tinymce-rails', '~> 4.6.7'
gem 'uglifier'
gem 'will_paginate'

group :production do
  gem 'puma'
  gem 'rack-cors'
  gem 'rack-timeout'
  gem 'rails_12factor'
end

group :development do
  gem 'haml-lint', require: false
  gem 'listen'
  gem 'memory_profiler'
  gem 'rack-mini-profiler'
  gem 'rubocop', '~> 0.74.0', require: false
  gem 'rubocop-performance', '~> 1.4.0', require: false
  gem 'rubocop-rails', '~> 2.2.1', require: false
  gem 'traceroute'
  gem 'web-console', '~> 3.0'
end

group :development, :test do
  gem 'byebug'
  gem 'database_cleaner'
  gem 'dotenv-rails'
  gem "html-proofer"
  gem 'rake', '~> 12.0'
  gem 'rspec-rails'
  gem 'seed_dump', '~> 3.2'
  gem 'thin'
end

group :test do
  gem 'capybara'
  gem 'factory_bot_rails'
  gem 'json'
  gem 'rails-controller-testing'
  gem 'resque_spec'
  gem 'simplecov'
  gem 'timecop'
  gem 'webmock'
end
