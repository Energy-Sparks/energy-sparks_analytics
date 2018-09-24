# test report manager
require 'require_all'
require_relative '../lib/dashboard.rb'
require_rel '../test_support'
require './script/report_config_support.rb'

# school_name = 'Westfield Primary' 
module Logging
  @logger = Logger.new('Results/test-simulator ' + Time.now.strftime('%H %M') + '.log')
  @logger.level = :debug # :debug
end
ENV['AWESOMEPRINT'] = 'off'

puts "========================================================================================"
puts  "Heating Model Fitting"

suppress_school_loading_output = true

reports = ReportConfigSupport.new

list_of_schools = reports.schools.keys

list_of_schools.each do |school_name|
  school_name = 'St Marks Secondary'
  puts "Processing #{school_name}"

  school = reports.load_school(school_name, suppress_school_loading_output)

  next if school.aggregated_heat_meters.nil?

  heat_amr_data = school.aggregated_heat_meters.amr_data

  bm = Benchmark.measure {
    start_date = heat_amr_data.start_date
    end_date = heat_amr_data.end_date
    period = SchoolDatePeriod.new(:fitting, 'Meter Period', start_date, end_date)

    puts "-" * 90
    puts "calculating simple model"
    simple_model = AnalyseHeatingAndHotWater::BasicRegressionHeatingModel.new(heat_amr_data, school.holidays, school.temperatures)
 
    for temperature in (8..30).step(0.5)
      simple_model.base_degreedays_temperature = temperature
      simple_model.calculate_regression_model(period)
      sd, mean = simple_model.cusum_standard_deviation_average
      if sd.nan? || mean.nan?
        puts "simple: t = #{temperature} NaN"
      else
        puts "simple: t = #{temperature} sd = #{sd.round(0)} mean = #{mean.round(0)}"
      end
    end

    puts "-" * 90
    puts "calculating heavy thermal mass model"
    thermal_mass_model = AnalyseHeatingAndHotWater::HeatingModelWithThermalMass.new(heat_amr_data, school.holidays, school.temperatures)
 
    for temperature in (8..30).step(0.5)
      thermal_mass_model.base_degreedays_temperature = temperature
      thermal_mass_model.calculate_regression_model(period)
      sd, mean = thermal_mass_model.cusum_standard_deviation_average
      if sd.nan? || mean.nan?
        puts "heavy: t = #{temperature} NaN"
      else
        puts "heavy: t = #{temperature} sd = #{sd.round(0)} mean = #{mean.round(0)}"
      end
    end
  }

  puts "Fitting took: #{bm.to_s}"

  reports.do_one_page(:heating_model_fitting)

  reports.save_excel_and_html

  reports.report_benchmarks

  exit # do only one school for the moment
end

