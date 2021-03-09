# test report manager
require 'require_all'
require_relative '../../lib/dashboard.rb'
require_rel '../../test_support'
require './script/report_config_support.rb'

script = {
  logger1:                  { name: TestDirectoryConfiguration::LOG + "/datafeeds %{time}.log", format: "%{severity.ljust(5, ' ')}: %{msg}\n" },
  schools:                  ['n3*'],
  source:                   :unvalidated_meter_data,
  logger2:                  { name: "./log/management summary %{school_name} %{time}.log", format: "%{datetime} %{severity.ljust(5, ' ')}: %{msg}\n" },
  management_summary_table:          {
      control: {
        combined_html_output_file:     "Management Summary Table #{Date.today}",
        compare_results: [
          { comparison_directory: 'C:\Users\phili\Documents\TestResultsDontBackup\Management Summary Table\Base' },
          { output_directory:     'C:\Users\phili\Documents\TestResultsDontBackup\Management Summary Table\New' },
          :summary,
          :report_differences
        ]
      }
    }
}

RunTests.new(script).run
