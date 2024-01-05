# Report Manager - manages groups of charts
# require_relative 'chartmanager'

class ReportManager
  include Logging
  attr_reader :standard_reports
  def initialize(school)
    @school = school
    @chart_manager = ChartManager.new(school)
    configure_standard_reports
  end

  def configure_standard_reports
    @standard_reports = {
=begin
     # 'Main Dashboard'        => %i[benchmark daytype_breakdown group_by_week_gas group_by_week_electricity],
     # 'Heat Analysis'         => %i[thermostatic cusum summer_hot_water],
      'Summary'                  => %i[day_of_week group_by_month day],
      'Heating and Hot Water'    => %i[group_by_week thermostatic hotwater],
      'Electricity'              => %i[group_by_week_electric baseload electricity_year electricity_acyear],
      'Thermostatic'             => %i[group_by_week cusum],
      'Benchmark'                => %i[benchmark intraday_line]
      'Thermostatic'             => %i[day_of_week intraday_line] # day_of_week] # thermostatic daytype_breakdown group_by_week day group_by_month ]
      'test1'                    => %i[last_week_by_day group_by_month]
      'test2'                    => %i[group_by_month_2_schools]

'Main Dashboard'        => %i[benchmark daytype_breakdown group_by_week_gas group_by_week_electricity group_by_week_gas_kwh_pupil gas_latest_year],
'Test Y Axis Scaling'   => %i[group_by_week_gas group_by_week_gas_kw group_by_week_gas_kwh group_by_week_gas_kwh_pupil group_by_week_gas_co2_floor_area group_by_week_gas_library_books]
=end
'Test 1'         => %i[benchmark daytype_breakdown group_by_week_gas group_by_week_electricity],
'Test 2'         => %i[group_by_week_gas_kwh_pupil gas_latest_years gas_latest_academic_years],
'Test 3'         => %i[gas_by_day_of_week electricity_by_day_of_week electricity_by_month_acyear_0_1],
'Test 4'         => %i[thermostatic cusum baseload intraday_line],
'Test 5'         => %i[gas_kw group_by_week_gas_kwh group_by_week_gas_kwh_pupil group_by_week_gas_co2_floor_area group_by_week_gas_library_books]
  #
  #                        gas_by_day_of_week electricity_by_day_of_week electricity_by_month_acyear_0_1
  #                        thermostatic cusum baseload],
# 'Main Dashboard'        => %i[intraday_line] # group_by_week_electricity]
# 'Main Dashboard'        => %i[benchmark daytype_breakdown group_by_week_gas group_by_week_electricity
#                              group_by_week_gas_kwh_pupil gas_latest_years gas_latest_academic_years
#                        gas_by_day_of_week electricity_by_day_of_week electricity_by_month_acyear_0_1
#                        thermostatic cusum baseload],
    }
  end

  def run_reports(reports)
    worksheet_charts = {}
    reports.each do |page_name, list_of_charts| # aka a web page containing a series of graphs
      logger.debug "Creating a webpage/excel worksheet #{page_name}"
      list_of_charts.each do |chart_type|
        worksheet_charts[page_name] = [] unless worksheet_charts.key?(page_name)
        chart = create_chart(chart_type)
        unless chart.nil?
          worksheet_charts[page_name].push(chart)
        end
      end
    end
    worksheet_charts # [worksheet name] = [ charts ]
  end

  def create_chart(chart_type)
    logger.info "Running chart ===========================#{chart_type}==========================="
    @chart_manager.run_standard_chart(chart_type)
  end
end
