require 'require_all'
require_relative '../../lib/dashboard.rb'
require_rel '../../test_support'

script = {
  logger1:                  { name: TestDirectoryConfiguration::LOG + "/datafeeds %{time}.log", format: "%{severity.ljust(5, ' ')}: %{msg}\n" },
  # ruby_profiler:            true,
  no_schools:                  ['marks*', 'stanton*', 'penny*', 'plump*',
                              'combe*', 'catsfield', 'miller*','tomnac*',
                              'king-e*'
                            ],
  schools: ['rogerstone*'],
  source:                   :unvalidated_meter_data,
  logger2:                  { name: "./log/pupil dashboard %{school_name} %{time}.log", format: "%{datetime} %{severity.ljust(5, ' ')}: %{msg}\n" },
  adult_dashboard:          {
                              control: {
                                root:    :adult_analysis_page, # :pupil_analysis_page,
                                no_chart_manipulation: %i[drilldown timeshift],
                                display_average_calculation_rate: true,
                                summarise_differences: true,
                                report_failed_charts:   :summary, # :detailed
                                user: { user_role: :analytics, staff_role: nil },

                                no_pages: %i[electric_target gas_target storage_heater_target],
                                pages: %i[electric_target gas_target],
                                compare_results: [
                                  { comparison_directory: ENV['ANALYTICSTESTRESULTDIR'] + '\AdultDashboard\Base' },
                                  { output_directory:     ENV['ANALYTICSTESTRESULTDIR'] + '\AdultDashboard\New' },
                                  :summary,
                                  #:report_differences,
                                  #:report_differing_charts,
                                ] # :quick_comparison,
                              }
                            }
}

RunTests.new(script).run
