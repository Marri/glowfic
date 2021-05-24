source 'https://rubygems.org'

ruby '2.6.7'

gem 'api-pagination'
gem 'apipie-rails'

# when upgrading check:
# - for migrations with `rails generate audited:upgrade`
# - that the method set_audit_user has not changed, since we duplicate it in
#   ApplicationRecord for use in callbacks to send audit user ids to background jobs.
#   (currently https://github.com/collectiveidea/audited/blob/v4.9.0/lib/audited/audit.rb#L175)
gem 'audited', '~> 4.9.0'

gem 'aws-sdk-rails', '~> 2'
gem 'aws-sdk-s3', '~> 1'
gem 'aws-sdk-ses', '~> 1'
gem 'barnes' # heroku ruby-specific metrics
gem 'bootstrap', '~> 4.5' # pin until major version is handled
gem 'exception_notification'
gem 'get_process_mem'
gem 'gon', '~> 6.4.0'
gem 'haml-rails'
gem 'httparty'
gem 'jquery-fileupload-rails'
gem 'jquery-rails', '>= 4.3.4'
gem 'jquery-ui-rails'
gem 'json', '>= 2.3.0'
gem 'jwt'
gem 'newrelic_rpm'
gem 'nilify_blanks'
gem 'nokogiri'
gem 'pg', '~> 1.1.4'
gem 'pg_search'
gem 'rack-pratchett'
gem 'rails', '~> 5.2.0'
gem 'redis', '~> 4.0'
gem 'redis-rails'
gem 'resque'
gem 'resque_mailer'
gem 'sanitize'
gem 'sassc-rails'
gem 'select2-rails'
gem 'sprockets', '~> 3.7' # pin sprockets until we deal with its major upgrade
gem 'test-unit', '~> 3.0' # required by Heroku for production console
gem 'tinymce-rails'
gem 'uglifier'
gem 'will_paginate'

group :production do
  gem 'puma'
  gem 'rack-cors'
  gem 'rack-timeout', '>= 0.6.0'
  gem 'resque-heroku-signals'
end

group :development do
  gem 'haml_lint', '~> 0.37.0', require: false
  gem 'listen'
  gem 'memory_profiler'
  gem 'rack-mini-profiler'
  gem 'rubocop', '~> 1.15.0', require: false
  gem 'rubocop-performance', '~> 1.11.3', require: false
  gem 'rubocop-rails', '~> 2.10.1', require: false
  gem 'rubocop-rspec', '~> 2.3.0', require: false
  gem 'traceroute'
end

group :development, :test do
  gem 'byebug'
  gem 'database_cleaner'
  gem 'dotenv-rails'
  gem 'html-proofer'
  gem 'rake', '~> 12.0'
  gem 'rspec-rails'
  gem 'seed_dump', '~> 3.2'
  gem 'thin'
end

group :test do
  gem 'capybara'
  gem 'factory_bot_rails'
  gem 'rails-controller-testing'
  gem 'resque_spec'
  gem 'selenium-webdriver'
  gem 'simplecov', '~> 0.17.1'
  gem 'timecop'
  gem 'webdrivers', '~> 4.0'
  gem 'webmock'
end
