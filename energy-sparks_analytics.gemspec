
# -*- encoding: utf-8 -*-
# frozen_string_literal: true

$:.push File.expand_path("../lib", __FILE__)
require "dashboard/version"

Gem::Specification.new do |s|
  s.name        = "energy-sparks_analytics"
  s.version     = Dashboard::VERSION.dup
  s.platform    = Gem::Platform::RUBY
  s.licenses    = ["MIT"]
  s.summary     = "Energy sparks - analytics"
  s.homepage    = "https://github.com/BathHacked/energy_sparks"
  s.description = "Energy sparks - analytics - for charting"
  s.authors     = ['Philip Haile']
  # s.files         = `git ls-files`.split("\n")
  # s.test_files    = `git ls-files -- rspec/*`.split("\n")
  s.require_paths = ["lib"]
  s.required_ruby_version = '>= 2.5.0'

  s.add_dependency 'require_all', '~> 2.0.0'
  s.add_dependency 'activesupport', '~> 6.0.0'
  s.add_dependency 'statsample', '~> 2.1.0'
  s.add_dependency 'mechanize', '~> 2.7.6'
  s.add_dependency 'write_xlsx', '~> 0.85.5'
  s.add_dependency 'roo', '~> 2.7.1'
  s.add_dependency 'roo-xls', '~> 1.2.0'
  s.add_dependency 'html-table', '~> 1.5.1'
  s.add_dependency 'interpolate', '~> 0.3.0'
  s.add_dependency 'ruby-sun-times', '~> 0.1.5'
  s.add_dependency 'soda-ruby', '~> 0.2.25'
  s.add_dependency 'structured_warnings', '~> 0.3.0'
  s.add_dependency 'chroma', '~> 0.2.0'
  s.add_dependency 'hashdiff', '~> 1.0.0'
  s.add_dependency 'faraday', '~> 1.0.1'
  s.add_dependency 'faraday_middleware', '~> 1.0.0'

  # For profiling code
  s.add_dependency 'ruby-prof', '~> 0.17.0'
  s.add_dependency 'benchmark-memory', '~> 0.1.2'

  # Useful for debugging
  s.add_dependency 'pry-byebug'
  # For testing
  s.add_dependency 'rspec'
end
