# frozen_string_literal: true

source 'https://rubygems.org'

ruby '~> 2.7.6'

gem 'activesupport', '~> 6.1.7'
gem 'chroma'
gem 'faraday'
gem 'faraday-retry'
gem 'html-table'
gem 'interpolate'
gem 'require_all'
gem 'roo', git: 'https://github.com/Energy-Sparks/roo.git', branch: 'bug-fix-branch'
gem 'roo-xls'
gem 'ruby-sun-times'
gem 'soda-ruby', require: 'soda'
# Forked statsample to do proper relases and to remove dependency on
# awesome_print which is no longer supported. Last official release of
# statsample also had a problem where it overrode the definition of Array#sum
# with dodgy results. This is fixed in master, which is what this release is
# based upon.
gem 'statsample', git: 'https://github.com/Energy-Sparks/statsample', tag: '2.1.1-energy-sparks',
                  branch: 'update-gems-and-awesome-print'
gem 'structured_warnings'
gem 'tzinfo-data', platforms: %i[mingw mswin x64_mingw]
gem 'write_xlsx'

# limit rate that we call api methods
gem 'ruby-limiter', '~> 1.1.0'

# Useful for debugging
gem 'hashdiff', '~> 1.0.0'
gem 'pry-byebug'

gem 'dotenv'

gem 'rollbar'

group :development, :test do
  gem 'rubocop'
  gem 'rubocop-performance'
  gem 'rubocop-rspec'
end

group :development do
  gem 'aws-sdk-s3'
  gem 'i18n-tasks', '~> 1.0.10'
  gem 'benchmark-memory'
  gem 'climate_control'
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
