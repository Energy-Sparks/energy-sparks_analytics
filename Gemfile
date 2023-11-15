# frozen_string_literal: true

source 'https://rubygems.org'

gemspec

gem 'roo', git: 'https://github.com/Energy-Sparks/roo.git', branch: 'bug-fix-branch'
# Forked statsample to do proper relases and to remove dependency on awesome_print which is no longer supported
# Last official release of statsample also had a problem where it overrode the definition of Array#sum with dodgy
# results
# This is fixed in master, which is what this release is based upon.
gem 'statsample', git: 'https://github.com/Energy-Sparks/statsample', branch: 'update-gems-and-awesome-print'
gem 'tzinfo-data', platforms: %i[mingw mswin x64_mingw]

# Useful for debugging
gem 'pry-byebug'

gem 'dotenv'

gem 'rollbar'

# gem 'rexml'

group :development do
  gem 'aws-sdk-s3'
  gem 'i18n-tasks'
  # For profiling code
  gem 'benchmark-memory'
  gem 'climate_control'
  gem 'rubocop'
  gem 'rubocop-rspec'
  gem 'rubocop-performance'
  gem 'ruby-prof'
end

# For tests
group :test do
  gem 'bundler-audit', platforms: :ruby
  gem 'factory_bot'
  gem 'rspec', '~> 3.12.0'
  gem 'simplecov', require: false

  # Used by rspec html matcher
  gem 'compare-xml'
  gem 'nokogiri'
end
