# test report manager
require 'require_all'
require_relative '../lib/dashboard.rb'
require_rel '../test_support'

def banner(title)
  cols = 120
  len_before = ((cols - title.length) / 2).floor
  len_after = cols - title.length - len_before
  '=' * len_before + title + '=' * len_after
end

@dashboard_page_groups = {
  main_dashboard_electric:  {
                              name:   'Main Dashboard',
                              charts: %i[benchmark_electric]
                            },
  electricity_year:         {
                              name:   'Electricity Year',
                              charts: %i[benchmark_electric]
                            },
  electricity_longterm:      {
                              name:   'Electricity Analysis -long term',
                              charts: %i[
                                daytype_breakdown_electricity
                                group_by_week_electricity
                                electricity_by_day_of_week
                                baseload
                                electricity_by_month_year_0_1
                                intraday_line_school_days
                                intraday_line_holidays
                                intraday_line_weekends
                              ]
                            },
  gas_thermostatic:      {
                              name:   'Gas Detail (thermostatic)',
                              charts: %i[
                                daytype_breakdown_gas
                                group_by_week_gas
                                gas_by_day_of_week
                                thermostatic
                                cusum
                              ]
                            },
  recent_electric:          {
                              name:   'Electricity Recent',
                              charts: %i[
                                intraday_line_school_days
                                intraday_line_school_days_last5weeks
                                intraday_line_school_days_6months
                                intraday_line_school_last7days
                                baseload_lastyear
                              ]
                            },
  main_dashboard_electric_and_gas: {
                              name:   'Main Dashboard',
                              charts: %i[
                                benchmark
                                daytype_breakdown_electricity
                                daytype_breakdown_gas
                                group_by_week_electricity
                                group_by_week_gas
                              ]
                            },
  electric_and_gas_year:    {
                              name:   'Electricity & Gas Year',
                              charts: %i[benchmark]
                            },
  recent_electric_and_gas:  {
                              name:   'Recent Electricity & Gas',
                              charts: %i[benchmark]
                            }
}

@school_report_groups = {
  electric_only:
                      %i[ main_dashboard_electric
                          electricity_year
                          electricity_longterm
                          recent_electric],
  electric_and_gas:
                      %i[ main_dashboard_electric_and_gas
                          electric_and_gas_year
                          electricity_longterm
                          gas_thermostatic
                          recent_electric],
  electric_and_gas_and_pv:
                      %i[ main_dashboard_electric_and_gas
                          electric_and_gas_year
                          electricity_longterm
                          gas_thermostatic
                          recent_electric_and_gas],
  electric_and_gas_and_storage_heater:
                      %i[ main_dashboard_electric_and_gas
                          electric_and_gas_year
                          electricity_longterm
                          gas_thermostatic
                          recent_electric_and_gas]
}

@schools = {
  'Bishop Sutton Primary School'      => :electric_and_gas,
  'Castle Primary School'             => :electric_and_gas,
  'Freshford C of E Primary'          => :electric_and_gas,
  'Marksbury C of E Primary School'   => :electric_only,
  'Paulton Junior School'             => :electric_and_gas_and_pv,
  'Pensford Primary'                  => :electric_only,
  'Roundhill School'                  => :electric_and_gas,
  'Saltford C of E Primary School'    => :electric_and_gas,
  'St Johns Primary'                  => :electric_and_gas,
  'Stanton Drew Primary School'       => :electric_and_gas_and_storage_heater,
  'Twerton Infant School'             => :electric_and_gas,
  'Westfield Primary'                 => :electric_and_gas
}

ENV[SchoolFactory::ENV_SCHOOL_DATA_SOURCE] = SchoolFactory::BATH_HACKED_SCHOOL_DATA
ENV['School Dashboard Advice'] = 'Include Header and Body'
$SCHOOL_FACTORY = SchoolFactory.new

puts "\n" * 8

@benchmarks = []

def do_all_schools
  @schools.keys do |school_name|
    do_one_school(school_name)
  end
end

def load_school(school_name)
  puts banner("School: #{school_name}")
  school = $SCHOOL_FACTORY.load_school(school_name)
end

def do_one_school(school_name, filter_page_name = nil, filter_chart = nil)
  report_config = @schools[school_name]
  puts "Doing this report configuration #{report_config}"
  worksheet_charts = {}

  school = load_school(school_name)

  chart_manager = ChartManager.new(school)

  do_all_pages_for_school(school, school_name, chart_manager, worksheet_charts, report_config, filter_page_name, filter_chart)

  @benchmarks.each do |bm|
    puts bm
  end
  @benchmarks = []
end


def do_all_pages_for_school(school, school_name, chart_manager, worksheet_charts,
                            report_config, filter_page_name, filter_chart)
  report_groups = @school_report_groups[report_config]

  report_groups.each do |report_page|
    next if !filter_page_name.nil? && report_page != filter_page_name
    do_one_page(school, report_page, chart_manager, worksheet_charts, filter_chart)
    puts "\n" * 3
    puts "got #{worksheet_charts.length} pages"
    puts "\n" * 3
  end

  do_excel(school_name, worksheet_charts)
  do_html(school_name, worksheet_charts)
end

def do_one_page(school, report_page, chart_manager, worksheet_charts, filter_chart = nil)
  page_config = @dashboard_page_groups[report_page]
  puts "\tRunning report page  #{page_config[:name]}"
  worksheet_charts[page_config[:name]] = [] unless worksheet_charts.key?(page_config[:name])
  page_config[:charts].each do |chart_name|
    next if !filter_chart.nil? && chart_name != filter_chart
    chart = do_one_chart(chart_name, chart_manager)
    unless chart.nil?
      worksheet_charts[page_config[:name]].push(chart)
      puts "Added chart to #{page_config[:name]}"
    end
  end
  puts "\n" * 3
  puts "got #{page_config[:name]} has #{worksheet_charts[page_config[:name]].length} charts"
  puts "\n" * 3
end

def do_one_chart(chart_name, chart_manager)
  puts banner(chart_name.to_s)
  chart = nil
  bm = Benchmark.measure {
    chart = chart_manager.run_standard_chart(chart_name)
  }
  @benchmarks.push(sprintf("%30.30s = %s", chart_name, bm.to_s))
  ap(chart, limit: 20, color: { float: :red })
  chart
end

def do_excel(school_name, worksheet_charts)
  excel = ExcelCharts.new(File.join(File.dirname(__FILE__), '../Results/') + school_name + '- charts test.xlsx')
  worksheet_charts.each do |worksheet_name, charts|
    excel.add_charts(worksheet_name, charts)
  end

  excel.close
end

def do_html(school_name, worksheet_charts)
  html_file = HtmlFileWriter.new(school_name)
  worksheet_charts.each do |worksheet_name, charts|
    html_file.write_header(worksheet_name)
    charts.each do |chart|
      html_file.write_header_footer(chart[:config_name], chart[:advice_header], chart[:advice_footer])
    end
  end
  html_file.close
end

# example testing choices:
#
#   1. do_all_schools
#
#   2. do_one_school('Bishop Sutton Primary School')
#
#   3. do_one_school('Bishop Sutton Primary School', :main_dashboard_electric_and_gas)
#
#   4. do_one_school('Bishop Sutton Primary School', :main_dashboard_electric_and_gas, :benchmark)
#
# do_all_schools

do_one_school('Bishop Sutton Primary School', , :main_dashboard_electric_and_gas, :benchmark))

