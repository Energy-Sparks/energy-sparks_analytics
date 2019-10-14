require_rel './run_charts.rb'
class PupilDashboardTests < RunCharts

  def initialize(school)
    super(school)
    @chart_manager = ChartManager.new(school)
  end

  def run_tests(control)
    run_recursive_dashboard_page(:pupil_analysis_page)
    save_to_excel
    write_html
    # CompareChartResults.new(control[:compare_results], @school.name).compare_results(all_charts)
    # log_results
  end

  private def run_recursive_dashboard_page(parent_page_config)
    puts 'run_recursive_dashboard_page'
    pages = []
    config = DashboardConfiguration::DASHBOARD_PAGE_GROUPS[parent_page_config]
    flatten_recursive_page_hierarchy(config, pages)
    pages.each do |page|
      page.each do |page_name, charts|
        charts.each do |chart_name|
          chart_results = nil
          begin
            chart_config = @chart_manager.get_chart_config(chart_name)
            chart_results = @chart_manager.run_chart(chart_config, chart_name)
            chart_results[:title] += title_addendum(chart_config)
            @worksheets[page_name].push(chart_results)
            depth = 0
            loop do
              chart_name, chart_config, chart_results = drilldown(chart_results, page_name, chart_name, chart_config)
              puts "#{page_name} #{chart_name}"
              break if chart_name.nil?
              depth += 1
              if depth > 4
                puts "===" * 50
                break
              end
              chart_results[:title] += title_addendum(chart_config)
              @worksheets[page_name].push(chart_results)
            end
          rescue StandardError => e
            puts "Chart #{chart_name} failed: #{e.message}"
          end
        end
      end
    end
  end

  private def title_addendum(chart_config)
    up_timescale = "[Parent timescale #{@chart_manager.parent_chart_timescale_description(chart_config)}]"
    drilldown = @chart_manager.drilldown_available?(chart_config) ? '[drilldown available]' : '[drilldown unavailable]'
    move = move_forward_back_one_time_unit_availability_description(chart_config)
    drilldown + up_timescale + move
  end

  private def move_forward_back_one_time_unit_availability_description(chart_config)
    move = ChartManagerTimescaleManipulationMove.factory(:move, chart_config, @school)
    return "[move not available]" unless move.chart_suitable_for_timescale_manipulation?
    forward = move.can_go_forward_in_time_one_period? ? 'available' : 'unavailable'
    back = move.can_go_back_in_time_one_period? ? 'available' : 'unavailable'
    "[move forward: #{forward}, move back: #{back}]"
  end

  private def drilldown(chart_result, page_name, chart_name, chart_config)
    if @chart_manager.drilldown_available?(chart_config)
      fourth_column_in_chart = chart_result[:x_axis_ranges][0]
      new_chart_name, new_chart_config = @chart_manager.drilldown(chart_name, chart_config, nil, fourth_column_in_chart)
      new_chart_results = @chart_manager.run_chart(new_chart_config, new_chart_name)
      return [new_chart_name, new_chart_config, new_chart_results]
    end
    [nil, nil, nil]
  end

  private def excel_variation
    '- pupil analysis'
  end

  private def flatten_recursive_page_hierarchy(parent_page,  pages, name = '')
    if parent_page.is_a?(Hash)
      if parent_page.key?(:sub_pages)
        parent_page[:sub_pages].each do |sub_page|
          next unless fuel_type_available(name)
          new_name = name + sub_page[:name] if sub_page.is_a?(Hash) && sub_page.key?(:name)
          flatten_recursive_page_hierarchy(sub_page,  pages, new_name)
        end
      else
        pages.push({ name => parent_page[:charts] })
      end
    else
      puts 'Error in recursive dashboard definition'
    end
  end

  private def fuel_type_available(name)
    case name
    when 'Electricity'
      @school.electricity? && !@school.solar_pv_panels?
    when 'Gas'
      @school.gas?
    when 'Storage Heaters'
      @school.storage_heaters?
    when 'Electricity+Solar PV'
      @school.electricity? && @school.solar_pv_panels?
    else
      true
    end
  end
end