require 'require_all'
require_relative '../lib/dashboard.rb'
require_rel '../test_support'
ENV['ENERGYSPARKSTESTMODE'] = 'ON'

script = {
  logger1:                  { name: TestDirectoryConfiguration::LOG + "/benchmark db %{time}.log", format: "%{severity.ljust(5, ' ')}: %{msg}\n" },
  # ruby_profiler:            true,
  schools:                  ['*'],
  source:                   :unvalidated_meter_data,
  logger2:                  { name: "./log/benchmark %{school_name} %{time}.log", format: "%{datetime} %{severity.ljust(5, ' ')}: %{msg}\n" },
  
  run_benchmark_charts_and_tables: {
    filename:       './TestResults/benchmark database',
    no_transform_frontend_yaml: { 
      from_filename: './TestResults/benchmark_results_data',
      to_filename:   './TestResults/benchmark_results_data analytics'
    },
    # filename:       './TestResults/benchmark_results_data analytics',

    calculate_and_save_variables: true,
    asof_date:      Date.new(2020, 10, 6),
    # asof_date:      Date.new(2019,11,25),
    # filter:         ->{ addp_area.include?('Sheffield') },
    # run_charts_and_tables: Date.new(2019,10,16),
    run_content:    {
      asof_date:      Date.new(2020,10,6),
      # asof_date:      Date.new(2019,11,25),
      user:          { user_role: :admin }, # { user_role: :analytics, staff_role: nil }, # { user_role: :admin }, 
      filter:        nil, #->{ addp_area.include?('Bath') } # ->{ addp_area.include?('Sheffield') } # nil || addp_area.include?('Highland') },
    },
    compare_results: [
      :report_differences,
      { comparison_directory: 'C:\Users\phili\Documents\TestResultsDontBackup\Benchmark\Base\\' },
      { output_directory:     'C:\Users\phili\Documents\TestResultsDontBackup\Benchmark\New\\' }
    ]
  }
}

RunTests.new(script).run
