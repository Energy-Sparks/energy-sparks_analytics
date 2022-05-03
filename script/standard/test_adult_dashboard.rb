require 'require_all'
require_relative '../../lib/dashboard.rb'
require_all './test_support/'

# try https://github.com/SamSaffron/memory_profiler

module Logging
  @logger = Logger.new('log\logs.log')
  logger.level = :error
end

require 'memory_profiler'

pages = DashboardConfiguration::ADULT_DASHBOARD_GROUPS[:boiler_control_group]
overrides = {
  schools: ['*'], # ['bxxxxalli*', 'wimble*'],
  control: { cache_school: false },
  ruby_profiler:  false,
  # adult_dashboard: { control: { pages: pages } },
  # adult_dashboard: { control: { pages: %i[boiler_control_seasonal]}},
  # adult_dashboard: { control: { pages: %i[boiler_control_seasonal], user: { user_role: :analytics, staff_role: nil } } }
  # adult_dashboard: { control: { pages: %i[boiler_control_morning_start_time], user: { user_role: :analytics, staff_role: nil } } }
  # adult_dashboard: { control: { pages: %i[ baseload], compare_results: [ :summary, :report_differences] } }
}

script = RunAdultDashboard.default_config.deep_merge(overrides)

# report = MemoryProfiler.report do
  RunTests.new(script).run
# end

# report.pretty_print
