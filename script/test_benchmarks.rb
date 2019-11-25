require 'require_all'
require_relative '../lib/dashboard.rb'
require_rel '../test_support'
ENV['ENERGYSPARKSTESTMODE'] = 'ON'

=begin
puts "=" * 100
x = YAML.load_file('TestResults\benchmark database.yaml')
ap x
puts ">" * 100
y = YAML.load_file('TestResults\benchmark_results_data.yaml')
# ap y, limit: 5
puts "-" * 100
y.each do |date, schools|
  schools.each do |school_id, variables|
    schools[school_id] = variables.transform_keys { |key| key.to_sym }
  end
end
ap y

exit
=end

script = {
  logger1:                  { name: TestDirectoryConfiguration::LOG + "/benchmark db %{time}.log", format: "%{severity.ljust(5, ' ')}: %{msg}\n" },
  # ruby_profiler:            true,
  schools:                  ['.*'], # ['White.*', 'Trin.*', 'Round.*' ,'St John.*'],
  source:                   :analytics_db, # :aggregated_meter_collection, 
  logger2:                  { name: "./log/benchmark %{school_name} %{time}.log", format: "%{datetime} %{severity.ljust(5, ' ')}: %{msg}\n" },
  
  run_benchmark_charts_and_tables: {
    filename:       './TestResults/benchmark database',
    no_transform_frontend_yaml: { 
      from_filename: './TestResults/benchmark_results_data',
      to_filename:   './TestResults/benchmark_results_data analytics'
    },
    # filename:       './TestResults/benchmark_results_data analytics',

    calculate_and_save_variables: true,
    asof_date:      Date.new(2019, 10, 16),
    # asof_date:      Date.new(2019,11,25),
    # filter:         ->{ addp_area.include?('Sheffield') },
    # run_charts_and_tables: Date.new(2019,10,16),
    run_content:    {
      asof_date:      Date.new(2019,10,16),
      # asof_date:      Date.new(2019,11,25),
      filter:         ->{ addp_area.include?('Bath') } # ->{ addp_area.include?('Sheffield') } # nil || addp_area.include?('Highland') },
    }
  }
}

RunTests.new(script).run
