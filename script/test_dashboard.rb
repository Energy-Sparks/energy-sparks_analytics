# test report manager
require 'ruby-prof'
require 'benchmark/memory'
require 'require_all'
require_relative '../lib/dashboard.rb'
require_rel '../test_support'
require './script/report_config_support.rb'

module Logging
  @logger = Logger.new('log/test-dashboard ' + Time.now.strftime('%H %M') + '.log')
  # @logger = Logger.new(STDOUT)
  logger.level = :debug
end

@@parameterised = false
@@dontcachecalculatedco2costdata = true

profile = false

if false
  @@energysparksanalyticsautotest = {
    original_data: '../TestResults/Charts/Base/',
    new_data:      '../TestResults/Charts/New/',
    skip_advice:   true
  }
end

# CO2Parameterised.create_uk_grid_carbon_intensity_from_parameterised_data
# ScheduleDataManager.uk_grid_carbon_intensity

reports = ReportConfigSupport.new

RubyProf.start if profile

# reports.load_school('King Edward VII Upper School', true)
# reports.load_school('Paulton Junior School', true)
# reports.load_school('St Marks Secondary', true)
# reports.load_school('Whiteways Primary', true)
# reports.load_school('Trinity First School', true)
# 'Wybourn Primary School'

if false
  Benchmark.memory do |x|
    x.report("load school")  { reports.load_school('Whiteways Primary', true) }
  end
end

puts "Loading school"
bm = Benchmark.realtime {
  # reports.load_school('Whiteways Primary', true)
  reports.load_school('Whiteways Primary', true)
}
puts "Load time: #{bm.round(3)} seconds"



# reports.load_school('Paulton Junior School', true)

# testing examples
#
#   reports.do_all_schools(true)
#   reports.do_all_standard_pages_for_school
#   reports.do_one_page(:main_dashboard_electric_and_gas)
#   reports.do_chart_list('Boiler Control', [:hotwater, :frost_2, :optimum_start])
#

# reports.do_chart_list('Boiler Control', [:gas_heating_season_intraday, :gas_heating_season_intraday_£])

# @@energysparksanalyticsautotest[:name_extension] = 'y_axis_scale to £' if defined?(@@energysparksanalyticsautotest)
# reports.do_all_standard_pages_for_school({yaxis_units: :£})
# reports.do_chart_list('kW scaling', [:intraday_line_school_last7days])
# reports.do_all_schools(true)
# reports.do_all_schools(true)
# reports.do_one_page(:cost)
# reports.do_all_schools(true)
# reports.do_all_standard_pages_for_school({yaxis_units: :£})
# reports.do_one_page(:carbon_emissions)
# reports.do_one_page(:cost)
# reports.do_all_schools(true)

# @@energysparksanalyticsautotest[:name_extension] = 'y_axis_scale to £' if defined?(@@energysparksanalyticsautotest)
# reports.do_all_standard_pages_for_school({yaxis_units: :co2})
# reports.do_all_standard_pages_for_school
# reports.do_chart_list('pound scaling', [:test_last_2_weeks_gas, :last_2_weeks_gas])

# reports.do_all_schools(true)
# reports.do_chart_list('hot water advice', [:hotwater])

@@energysparksanalyticsautotest[:name_extension] = 'y_axis_scale to co2' if defined?(@@energysparksanalyticsautotest)
reports.do_all_standard_pages_for_school({yaxis_units: :co2})

if profile
  prof_result = RubyProf.stop
  printer = RubyProf::GraphHtmlPrinter.new(prof_result)
  printer.print(File.open('log\code-profile - test_dashboard' + Date.today.to_s + '.html','w')) # 'code-profile.html')
end

reports.save_excel_and_html

reports.report_benchmarks
