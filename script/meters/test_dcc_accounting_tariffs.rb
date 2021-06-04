require 'require_all'
require_relative '../../lib/dashboard.rb'
require_rel '../../test_support'

def test_script_config1(school_name_pattern_match, source_db, attribute_overrides)
  {
    logger1:                  { name: TestDirectoryConfiguration::LOG + "/dcc tariff %{time}.log", format: "%{severity.ljust(5, ' ')}: %{msg}\n" },
    schools:                    school_name_pattern_match,
    source:                     source_db,
    meter_attribute_overrides:  attribute_overrides,
    reports:                  {
      charts: [
        adhoc_worksheet: { name: 'Test', charts: %i[
          group_by_week_electricity_meter_breakdown
          ]},
      ],
      control: {
        report_failed_charts:   :summary, 
        compare_results:        [ 
          :summary, 
          { comparison_directory: 'C:\Users\phili\Documents\TestResultsDontBackup\Charts\Base' },
          { output_directory:     'C:\Users\phili\Documents\TestResultsDontBackup\Charts\New' },
          :report_differing_charts,
          :report_differences
        ]
      }
    }
  }
end

def test_script_config(school_name_pattern_match, source_db, attribute_overrides)
  {
    logger1:                  { name: TestDirectoryConfiguration::LOG + "/dcc tariff %{time}.log", format: "%{severity.ljust(5, ' ')}: %{msg}\n" },
    schools:                    school_name_pattern_match,
    source:                     source_db,
    meter_attribute_overrides:  attribute_overrides,
    adult_dashboard:          {
      control: {
        root:    :adult_analysis_page,
        report_failed_charts:   :summary,
        user:          { user_role: :analytics, staff_role: nil },
        pages: %i[electricity_profit_loss],
        compare_results: [
          { comparison_directory: 'C:\Users\phili\Documents\TestResultsDontBackup\AdultDashboard\Base' },
          { output_directory:     'C:\Users\phili\Documents\TestResultsDontBackup\AdultDashboard\New' },
          :summary,
          :report_differences,
        ]
      }
    }
  }
end

module Logging
  @logger = Logger.new('log/tariff testing ' + Time.now.strftime('%H %M') + '.log')
  logger.level = :debug
end

def load_all_accounting_tariffs
  Dir["./DCC/dcc-tariffs-meter-attributes-*.yaml"].map do |filename|
    [
      filename.delete("^0-9").to_i,
      YAML.load_file(filename) || {}
    ]
  end.to_h
end

def meter_attribute_overrides
  @meter_attribute_overrides ||= load_all_accounting_tariffs
end

# ap meter_attribute_overrides

school_name_pattern_match = ['Xwidcombe-jun*','king-j*'] # 'n3rgy*', 
source_db = :dcc_n3rgy_override_with_files
school_names = RunTests.resolve_school_list(source_db, school_name_pattern_match)

school_names.each do |school_name|
  school = SchoolFactory.new.load_or_use_cached_meter_collection(:name, school_name, source_db, meter_attributes_overrides: meter_attribute_overrides)
meter = school.meter?(1580001320420)
puts "kwh #{meter.amr_data.kwh_date_range(Date.new(2021, 4, 1), Date.new(2021, 4, 30))}"

band_kwh = DUOSCharges.kwh_in_bands_between_dates(meter, Date.new(2021, 4, 1), Date.new(2021, 4, 30))
ap band_kwh
puts band_kwh.values.sum
exit
end

script = test_script_config(school_name_pattern_match, source_db, meter_attribute_overrides)
RunTests.new(script).run
