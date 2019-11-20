require 'require_all'
require_relative '../lib/dashboard.rb'
require_rel '../test_support'

script = {
  logger1:                  { name: TestDirectoryConfiguration::LOG + "/datafeeds %{time}.log", format: "%{severity.ljust(5, ' ')}: %{msg}\n" },
  # ruby_profiler:            true,
  schools:                  ['.*'], # ['White.*', 'Trin.*', 'Round.*' ,'St John.*'],
  source:                   :analytics_db, # :aggregated_meter_collection, 
  logger2:                  { name: "./log/reports %{school_name} %{time}.log", format: "%{datetime} %{severity.ljust(5, ' ')}: %{msg}\n" },
  alerts:                   {
    alerts:   [ AlertSchoolWeekComparisonElectricity ], # nil, 
    control:  {
                # print_alert_banner: true,
                # alerts_history: true,
                print_school_name_banner: true,
                # raw_variables_for_saving
                no_outputs:           %i[front_end_template_variables front_end_template_data front_end_template_tables front_end_template_table_data], # front_end_template_variables front_end_template_data raw_variables_for_saving],
                save_and_compare:  {
                                      summary:      true,
                                      h_diff:     { use_lcs: false, :numeric_tolerance => 0.000001 },
                                      data: %i[
                                        front_end_template_variables
                                        raw_variables_for_saving
                                        front_end_template_data
                                        front_end_template_chart_data
                                        front_end_template_table_data
                                      ]
                                    },

                save_priority_variables:  { filename: './TestResults/alert priorities.csv' },
                no_benchmark:          %i[school alert ], # detail],
                # asof_date:          (Date.new(2018,6,14)..Date.new(2019,6,14)).each_slice(7).map(&:first),
                asof_date:      Date.new(2019,10,16)
              } 
  }
}

RunTests.new(script).run
