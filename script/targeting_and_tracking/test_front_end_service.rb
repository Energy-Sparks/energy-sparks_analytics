require 'require_all'
require_relative '../../lib/dashboard.rb'
require_rel '../../test_support'

module Logging
  @logger = Logger.new('log/targetting startup ' + Time.now.strftime('%H %M') + '.log')
  logger.level = :debug
end

def test_script_config(school_name_pattern_match, source_db, attribute_overrides)
  {
    logger1:          { name: TestDirectoryConfiguration::LOG + "/target %{time}.log", format: "%{severity.ljust(5, ' ')}: %{msg}\n" },
    schools:          school_name_pattern_match,
    source:           source_db,
    meter_attribute_overrides:  attribute_overrides,
    logger2:          { name: "./log/pupil dashboard %{school_name} %{time}.log", format: "%{datetime} %{severity.ljust(5, ' ')}: %{msg}\n" },
    adult_dashboard:  {
                        control: {
                          root:    :adult_analysis_page,
                          display_average_calculation_rate: true,
                          summarise_differences: true,
                          report_failed_charts:   :summary,
                          user: { user_role: :analytics, staff_role: nil },
                          pages: %i[electric_target gas_target],

                          compare_results: [
                            { comparison_directory: ENV['ANALYTICSTESTRESULTDIR'] + '\Target\Base' },
                            { output_directory:     ENV['ANALYTICSTESTRESULTDIR'] + '\Target\New' },
                            :summary,
                            :report_differences,
                            :report_differing_charts,
                          ]
                        }
                      }
  }
end

def set_meter_attributes(schools, start_date = Date.new(2020, 9, 1), target = 0.9)
  schools.each do |school|
    %i[electricity gas storage_heater].each do |fuel_type|
      meter = school.aggregate_meter(fuel_type)
      next if meter.nil?

      attributes = meter.meter_attributes

      attributes[:targeting_and_tracking] = [
          {
            start_date: start_date,
            target:     target
          }
        ]

      pseudo_attributes = { Dashboard::Meter.aggregate_pseudo_meter_attribute_key(fuel_type) => attributes }
      school.merge_additional_pseudo_meter_attributes(pseudo_attributes)
    end
  end
end

def test_service(school)
  info = {}
  puts '=' * 80
  puts "Testing service for #{school.name}"
  %i[electricity gas storage_heater].each do |fuel_type|
    info[fuel_type] ||= {}
    puts "For fuel type #{fuel_type}"
    service = TargetsService.new(school, fuel_type)

    info[fuel_type][:relevance] = service.meter_present?
    if service.meter_present?
      info[fuel_type][:enough_data_to_set_target] = service.enough_data_to_set_target?
      info[fuel_type][:annual_kwh_required] = service.annual_kwh_estimate_required?
      info[fuel_type][:recent_data] = service.recent_data?
      info[fuel_type][:enough_holidays] = service.enough_holidays?
      info[fuel_type][:enough_temperature_data] = service.enough_temperature_data?
      info[fuel_type][:valid] = service.valid?
      info[fuel_type][:problems_with_holidays] = service.holiday_integrity_problems.join(' + ')
      info[fuel_type].merge!(service.analytics_debug_info)
      if service.valid?
        ap service.progress
      end
    end
    ap info
  end
  info
end

def column_names(stats)
  col_names = stats.map do |school_name, school_stats|
    school_stats.map do |fuel_type, s|
      s.keys.map { |st| "#{fuel_type} #{st.to_s}" }
    end
  end.flatten.uniq
end

def extract_data(stats, column_names)
  data = Array.new(column_names.length, nil)
  stats.each do |fuel_type, s|
    s.each do |type, result|
      col_name = "#{fuel_type} #{type.to_s}"
      col_num = column_names.index(col_name)
      data[col_num] = result
    end
  end
  puts "Data:"
  ap data
  data
end

def save_stats(stats)
  filename = './Results/targeting and tracking stats v2.csv'
  puts "Saving results to #{filename}"

  col_names = column_names(stats)
  ap col_names

  CSV.open(filename, 'w') do |csv|
    csv << ['school', col_names].flatten
    stats.each do |school_name, stat|
      csv << [school_name, extract_data(stat, col_names)].flatten
    end
  end
end

def school_factory
  $SCHOOL_FACTORY ||= SchoolFactory.new
end

school_name_pattern_match = ['*']
source_db = :unvalidated_meter_data

school_names = RunTests.resolve_school_list(source_db, school_name_pattern_match)

schools = school_names.map do |school_name|
  school_factory.load_or_use_cached_meter_collection(:name, school_name, source_db)
end

# set_meter_attributes(schools)

stats = {}

schools.each do |school|
  stats[school.name] = test_service(school)
end

save_stats(stats)

script = test_script_config(school_name_pattern_match, source_db, {})
RunTests.new(script).run
