require 'require_all'
require_relative '../../lib/dashboard.rb'
require_rel '../../test_support'

script = {
  logger1:                  { name: TestDirectoryConfiguration::LOG + "/model fitting %{time}.log", format: "%{severity.ljust(5, ' ')}: %{msg}\n" },
  schools:                  ['trinit*'],
  source:                   :unvalidated_meter_data,
  simulator:            {
    control: {
      display_average_calculation_rate: true,
      report_failed_charts:   :summary, 
      compare_results:        %i[summary quick_comparison]
    }
  }, 
}
RunTests.new(script).run
