require 'require_all'
require_relative '../lib/dashboard.rb'
require_rel '../test_support'
require './script/report_config_support.rb'
require 'ruby-prof'

profile = false

module Logging
  @logger = Logger.new('log/test export inversion ' + Time.now.strftime('%H %M') + '.log')
  logger.level = :debug
end

school_name_pattern_match = ['*urlong*']
source_db = :aggregated_meter_collection # :analytics_db

school_names = RunTests.resolve_school_list(source_db, school_name_pattern_match)

school_names.each do |school_name|
  puts "==============================Doing #{school_name} ================================"

  school = SchoolFactory.new.load_or_use_cached_meter_collection(:name, school_name, source_db)
  RubyProf.start if profile
  pv_amr = school.solar_pv_meter.amr_data
  start_date = pv_amr.end_date - 364
  end_date = pv_amr.end_date

  total_pv_prod = pv_amr.kwh_date_range(start_date, end_date)
  histo = pv_amr.histogram_half_hours_data([-0.000000001,10], date1: start_date, date2: end_date)
  puts "orig total = #{total_pv_prod} histo #{histo}"

  pv_amr.scale_kwh(-1, date1: start_date, date2: end_date)

  total_pv_prod = pv_amr.kwh_date_range(start_date, end_date)
  histo = pv_amr.histogram_half_hours_data([-10,0], date1: start_date, date2: end_date)
  puts "new total = #{total_pv_prod} histo #{histo}"

  pv_amr.scale_kwh(-1)

  total_pv_prod = pv_amr.kwh_date_range(start_date, end_date)
  histo = pv_amr.histogram_half_hours_data([-0.000000001,10], date1: start_date, date2: end_date)
  puts "reverted old total = #{total_pv_prod} histo #{histo}"

  pv_amr.scale_kwh(-1)

  total_pv_prod = pv_amr.kwh_date_range(start_date, end_date)
  histo = pv_amr.histogram_half_hours_data([-10,0], date1: start_date, date2: end_date)
  puts "revertered new total = #{total_pv_prod} histo #{histo}"

  puts "Invert #{Benchmark.realtime {pv_amr.scale_kwh(-1)}}"
  puts "Histo #{Benchmark.realtime {pv_amr.histogram_half_hours_data([-10,0])}}"

  export_meter = school.aggregated_electricity_meters.sub_meters.find { |meter| meter.name = SolarPVPanels::SOLAR_PV_EXPORTED_ELECTRIC_METER_NAME }
  pv_amr = export_meter.amr_data
  total_export = pv_amr.kwh_date_range(start_date, end_date)

  histo = pv_amr.histogram_half_hours_data([-0.10000000001,+0.10000000001])
  negative = histo[0] > (histo[2] * 10)
  puts "export = #{total_pv_prod} histo #{histo} negative #{negative}"

  pv_amr.scale_kwh(-1)

  total_export = pv_amr.kwh_date_range(start_date, end_date)
  histo = pv_amr.histogram_half_hours_data([-0.10000000001,+0.10000000001])
  negative = histo[0] > (histo[2] * 10)
  puts "export = #{total_pv_prod} histo #{histo} negative #{negative}"

  pv_amr.scale_kwh(-1)
  
  def invert_export_amr_data_if_positive(amr_data)
    histo = amr_data.histogram_half_hours_data([-0.10000000001,+0.10000000001])
    negative = histo[0] > (histo[2] * 10) # 90%
    message = negative ? "is negative therefore leaving unchanged" : "is positive therefore inverting to conform to internal convention"
    puts "Export amr pv data #{message}"
    amr_data.scale_kwh(-1) unless negative
    amr_data
  end

  pv_amr = invert_export_amr_data_if_positive(pv_amr)


  if profile
    prof_result = RubyProf.stop
    printer = RubyProf::GraphHtmlPrinter.new(prof_result)
    printer.print(File.open('log\code-profile - test_building_simulator' + Date.today.to_s + '.html','w')) # 'code-profile.html')
  end
end