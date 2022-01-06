source 'https://rubygems.org'

ruby '~> 2.7.4'

gem 'require_all'
gem 'activesupport', '~> 6.0.0'

# Forked statsample to do proper relases and to remove dependency on awesome_print which is no longer supported
# Last official release of statsample also had a problem where it overrode the definition of Array#sum with dodgy results
# This is fixed in master, which is what this release is based upon.
gem 'statsample', git: 'https://github.com/Energy-Sparks/statsample', tag: '2.1.1-energy-sparks', branch: 'update-gems-and-awesome-print'
gem 'mechanize'
gem 'write_xlsx'
gem 'roo'
gem 'roo-xls'
gem 'html-table'
gem 'interpolate'
gem 'ruby-sun-times'
gem 'soda-ruby', require: 'soda'
gem 'structured_warnings'
gem 'chroma'
gem 'faraday'
gem 'faraday_middleware'
gem 'tzinfo-data', platforms: [:mingw, :mswin, :x64_mingw]

# limit rate that we call api methods
gem 'ruby-limiter', '~> 1.1.0'

# Useful for debugging
gem 'pry-byebug'
gem 'hashdiff', '~> 1.0.0'

# For profiling code
gem 'ruby-prof'
gem "benchmark-memory"

# For tests
group :test do
  gem 'rspec', '~> 3.8.0'
  gem 'bundler-audit' if RUBY_PLATFORM=~ /win32/
  gem 'factory_bot'
  gem 'simplecov', require: false
end
