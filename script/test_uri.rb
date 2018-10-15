# test chart uri encoding/decoding
require 'require_all'
require_relative '../lib/dashboard.rb'
require_rel '../test_support'
require './script/report_config_support.rb'
# MAIN

=begin
class Hash
  def to_params
    params = ''
    stack = []

    each do |k, v|
      if v.is_a?(Hash)
        stack << [k,v]
      elsif v.is_a?(Array)
        stack << [k,Hash.from_array(v)]
      else
        params << "#{k}=#{v}&"
      end
    end

    stack.each do |parent, hash|
      hash.each do |k, v|
        if v.is_a?(Hash)
          stack << ["#{parent}[#{k}]", v]
        else
          params << "#{parent}[#{k}]=#{v}&"
        end
      end
    end

    params.chop! 
    params
  end

  def self.from_array(array = [])
    h = Hash.new
    array.size.times do |t|
      h[t] = array[t]
    end
    h
  end
end

=end

reports = ReportConfigSupport.new

school_name = 'St Marks Secondary'
ReportConfigSupport.suppress_output(school_name) {
  reports.load_school(school_name, true)
}

reports.worksheet_charts = {}
original_chart_results = []
decoded_chart_results = []
failed = []
passed = []

chart_list_for_page = DashboardConfiguration::DASHBOARD_PAGE_GROUPS[:main_dashboard_electric_and_gas][:charts]
chart_list_for_page += DashboardConfiguration::DASHBOARD_PAGE_GROUPS[:electricity_detail][:charts]
chart_list_for_page += DashboardConfiguration::DASHBOARD_PAGE_GROUPS[:gas_detail][:charts]
chart_list_for_page += DashboardConfiguration::DASHBOARD_PAGE_GROUPS[:boiler_control][:charts]
chart_list_for_page.push(:group_by_week_electricity_test_range)

chart_list_for_page.each do |chart_name|
  puts "=" * 100
  puts "Testing #{chart_name}"
  puts "=" * 100

  chart_config = ChartManager::STANDARD_CHART_CONFIGURATION[chart_name]
  chart_config = reports.chart_manager.resolve_chart_inheritance(chart_config)
  chart_result = reports.chart_manager.run_chart(chart_config, chart_name)
  original_chart_results.push(chart_result)
  puts 'Params:', chart_config.to_params

  chart_config = ChartManager::STANDARD_CHART_CONFIGURATION[chart_name]
  chart_config.delete(:min_combined_school_date)
  chart_config.delete(:max_combined_school_date)
  chart_config = reports.chart_manager.resolve_chart_inheritance(chart_config)
  worked, uri = reports.chart_manager.encode_uri(chart_config)

  if worked
    decoded_chart_config = reports.chart_manager.decode_uri(uri)
    chart_result = reports.chart_manager.run_chart(decoded_chart_config, chart_name)
    decoded_chart_results.push(chart_result)
    passed.push(uri)
    puts "Working URI #{uri}"
  else
    puts "ERROR " * 15
    puts "Failed:"
    decoded_chart_config = reports.chart_manager.decode_uri(uri)
    puts "Original Hash: #{chart_config}"
    puts "Decoded Hash:  #{decoded_chart_config}"
    failed.push([chart_config, decoded_chart_config])
    puts "URI #{uri}"
    exit
  end
end

reports.worksheet_charts['Original'] = original_chart_results
reports.worksheet_charts['Decoded'] = decoded_chart_results

reports.excel_name = 'URI Test'

reports.write_excel

puts "#{passed.length} URIs worked #{failed.length} failed"
puts "Failed Encode/Decode"
failed.each do |failure|
  puts "Original Hash: #{failure[0]}"
  puts "Decoded Hash:  #{failure[1]}"
  puts
end



