# test chart drilldown
require 'require_all'
require_relative '../lib/dashboard.rb'
require_rel '../test_support'
require './script/report_config_support.rb'

def list_all_standard_chart_timescales
  chart_list_for_page = DashboardConfiguration::DASHBOARD_PAGE_GROUPS[:main_dashboard_electric_and_gas][:charts]
  chart_list_for_page += DashboardConfiguration::DASHBOARD_PAGE_GROUPS[:electricity_detail][:charts]
  chart_list_for_page += DashboardConfiguration::DASHBOARD_PAGE_GROUPS[:gas_detail][:charts]
  chart_list_for_page += DashboardConfiguration::DASHBOARD_PAGE_GROUPS[:boiler_control][:charts]
  # chart_list_for_page =  [:electricity_by_month_year_0_1]

  chart_list_for_page.each do |chart_name|
    chart = ChartManager::STANDARD_CHART_CONFIGURATION[chart_name]
    puts sprintf('%-45.45s %-60.60s %-20.20s', chart_name, chart[:timescale], chart[:x_axis]) if chart.key?(:timescale) && chart.key?(:x_axis)
  end
end

def test_timescale_manipulation_on_standard_chart(existing_chart_config, existing_chart_name)
  chart_results = []

  chart_manager = @reports.chart_manager

  name = existing_chart_config[:name]
  chart_result = chart_manager.run_chart(existing_chart_config, existing_chart_name)
  chart_results.push(chart_result)

  new_chart_config = existing_chart_config.deep_dup

  @tests.each do |test|
    manipulator = ChartManagerTimescaleManipulation.factory(test[:command],  new_chart_config, chart_manager.school)
    unless manipulator.chart_suitable_for_timescale_manipulation?
      puts '*' * 100
      puts "Chart #{existing_chart_name} not suitable for timescale manipulation"
      puts '*' * 100
      @@chart_unsuitable.push("#{existing_chart_name}: #{test[:command]}")
      next
    end
    unless manipulator.enough_data?(test[:amount])
      puts '*' * 100
      puts "Chart #{existing_chart_name} not enough data for amount of #{test[:amount]}"
      puts '*' * 100
      @@not_enough_data .push(existing_chart_name)
      next
    end
    new_chart_config = manipulator.adjust_timescale(test[:amount])
    new_chart_config[:name] = name + test[:name] + ' units'
    chart_result = chart_manager.run_chart(new_chart_config, existing_chart_name)
    if chart_result.nil?
      puts '*' * 1000
      puts 'Unable to calculate chart for ' + new_chart_config.inspect
      puts '*' * 1000
      @@chart_result_nil.push("#{existing_chart_name}: #{test[:command]}x#{test[:amount]}")
    else
      chart_results.push(chart_result)
      @@completed_chart_count += 1
    end
  end

  chart_results
end

def list_charts(chart_list)
  chart_list.each do |chart_description|
    puts chart_description
  end
end

@@not_enough_data  = []
@@chart_unsuitable = []
@@chart_result_nil = []
@@completed_chart_count = 0

# MAIN

@tests = [
  { name: ' back 3',            command: :move,     amount: -3  },
  { name: ' out of range',      command: :extend,   amount:  0  },
  { name: ' forward 2',         command: :move,     amount:  2  },
  { name: ' back 3',            command: :move,     amount: -3  },
  { name: ' forward 3',         command: :move,     amount:  3  },
  { name: ' extend back 3',     command: :extend,   amount: -3  },
  { name: ' forward 1',         command: :move,     amount:  1  },
  { name: ' contract 2 RHS',    command: :contract, amount:  2  },
  { name: ' extend fwd 2',      command: :extend,   amount:  2  },
  { name: ' contract 2 LHS',    command: :contract, amount: -2  },
  { name: ' compare previous',  command: :compare,  amount: -1  }
]

@charts_for_test = {
  group_by_week_electricity:                        '1 year electricity',
  group_by_week_gas:                                '1 year gas',
  electricity_by_day:                               '1 week electricity',
  intraday_line_school_days_last5weeks:             'last 5 weeks compare',
  electricity_by_datetime:                          '1 day electricity',
  electricity_by_datetime_line_kw:                  '1 day electricity line',
  group_by_week_electricity_school_comparison_line: '1 year electricity x schools',
  teachers_landing_page_gas:                        'teachers dashboard gas',
  teachers_landing_page_electricity:                'teachers dashboard electric'
}

def worktab_name(chart_name)
  chart_name.to_s.camelize.delete(' ').truncate(31)
end
=begin
@charts_for_test = { group_by_week_electricity:  '1 year electricity' }
@tests = [  { name: ' compare previous(-2)',    command: :compare,     amount: -2  } ]
=end

@reports = ReportConfigSupport.new

school_name = 'St Marks Secondary'
ReportConfigSupport.suppress_output(school_name) {
  @reports.load_school(school_name, true)
}

if true
  tabs = %i[main_dashboard_electric_and_gas electricity_detail gas_detail boiler_control carbon_emissions]
  charts = tabs.map { |tab| DashboardConfiguration::DASHBOARD_PAGE_GROUPS[tab][:charts] }.flatten.uniq
  charts_with_name = charts.map { |chart| [chart, worktab_name(chart)] }.to_h
  @charts_for_test.merge!(charts_with_name)
end
@reports.worksheet_charts = {}

@charts_for_test.each do |chart_name, worksheet_name|
  # chart_config = @reports.chart_manager.resolve_chart_inheritance(ChartManager::STANDARD_CHART_CONFIGURATION[chart_name])
  chart_config = @reports.chart_manager.get_chart_config(chart_name)

  @reports.worksheet_charts[worksheet_name] = test_timescale_manipulation_on_standard_chart(chart_config, chart_name)
end

@reports.excel_name = 'Timescale Manipulation Test'

@reports.write_excel
$VERBOSE = nil # stops ruby complaining about top level variable access
puts "Unsuitable charts",  list_charts(@@chart_unsuitable.uniq) unless @@chart_unsuitable.empty?
puts "Nil charts #{@@chart_result_nil.join(',')}" unless @@chart_result_nil.empty?
puts "Not enough data charts x #{@@not_enough_data.length} #{@@not_enough_data.join(', ')}" unless @@not_enough_data.empty?
puts "#{@@completed_chart_count} charts completed #{@@chart_unsuitable.length + @@not_enough_data.length} didn't"
