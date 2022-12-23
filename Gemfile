source 'https://rubygems.org'

ruby '~> 2.7.6'

gem 'require_all'
# gem 'activesupport', '6.1.7'

# Forked statsample to do proper relases and to remove dependency on awesome_print which is no longer supported
# Last official release of statsample also had a problem where it overrode the definition of Array#sum with dodgy results
# This is fixed in master, which is what this release is based upon.
gem 'statsample', git: 'https://github.com/Energy-Sparks/statsample', tag: '2.1.1-energy-sparks', branch: 'update-gems-and-awesome-print'
gem 'write_xlsx'
gem 'roo'
gem 'roo-xls'
gem 'html-table'
gem 'interpolate'
gem 'ruby-sun-times'
gem 'soda-ruby', require: 'soda'
gem 'structured_warnings'
gem 'chroma'
# gem 'faraday', '2.7.2'
# gem 'faraday_middleware'
gem 'tzinfo-data', platforms: [:mingw, :mswin, :x64_mingw]

# limit rate that we call api methods
gem 'ruby-limiter', '~> 1.1.0'

# Useful for debugging
gem 'pry-byebug'
gem 'hashdiff', '~> 1.0.0'

gem 'dotenv'

gem 'rollbar'

group :development do
  gem 'aws-sdk-s3'
  gem 'i18n-tasks', '~> 1.0.10'
  # For profiling code
  gem 'ruby-prof'
  gem "benchmark-memory"
end

# For tests
group :test do
  gem 'rspec', '~> 3.8.0'
  gem 'bundler-audit', platforms: :ruby
  gem 'factory_bot'
  gem 'simplecov', require: false
end
