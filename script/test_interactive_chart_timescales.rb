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

  new_chart_config = existing_chart_config.dup

  @tests.each do |test|
    new_chart_config = chart_manager.adjust_timescale(existing_chart_name, new_chart_config, test[:command], test[:amount])
    new_chart_config[:name] = name + test[:name] + ' units'
    chart_result = chart_manager.run_chart(new_chart_config, existing_chart_name)
    if chart_result.nil?
      puts '*' * 1000
      puts 'Unable to calculate chart for ' + new_chart_config.inspect
      puts '*' * 1000
    else
      chart_results.push(chart_result)
    end
  end

  chart_results
end

# MAIN


@tests = [
  { name: ' back 3',            command: :move,     amount: -3  },
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
  electricity_by_datetime:                          '1 day electricity',
  electricity_by_datetime_line_kw:                  '1 day electricity line',
  group_by_week_electricity_school_comparison_line: '1 year electricity x schools'
}

=begin
@charts_for_test = { group_by_week_electricity:  '1 year electricity' }
@tests = [  { name: ' compare previous(-2)',    command: :compare,     amount: -2  } ]
=end

@reports = ReportConfigSupport.new

school_name = 'St Marks Secondary'
ReportConfigSupport.suppress_output(school_name) {
  @reports.load_school(school_name, true)
}

@reports.worksheet_charts = {}

@charts_for_test.each do |chart_name, worksheet_name|
  chart_config = @reports.chart_manager.resolve_chart_inheritance(ChartManager::STANDARD_CHART_CONFIGURATION[chart_name])

  @reports.worksheet_charts[worksheet_name] = test_timescale_manipulation_on_standard_chart(chart_config, chart_name)

end

@reports.excel_name = 'Timescale Manipulation Test'

@reports.write_excel
