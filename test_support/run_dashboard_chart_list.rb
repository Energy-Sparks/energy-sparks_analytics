class RunDashboardChartList < RunCharts
  private def excel_variation; '- dashboard chart list' end
  private def name; 'Running charts for dashboard component' end
  private def short_name; 'dashboard component' end


  def dashboard_configs
    nil
  end

  def precalculation; nil end
  def meters; nil end

  def run(control)
    precalculation

    dashboard_configs.each do |dashboard_config|
      page_config = DashboardConfiguration::DASHBOARD_PAGE_GROUPS[dashboard_config]
      meters.uniq.each do |meter|
        puts "Doing #{@school.name} #{meter.mpan_mprn}"
        run_single_dashboard_page(page_config, meter.mpan_mprn)
      end
    end
    save_to_excel
    write_html("- #{short_name}")
    save_chart_calculation_times
    report_calculation_time(control)
    CompareChartResults.new(control[:compare_results], @school.name).compare_results(all_charts)
    log_results
  end

  def run_single_dashboard_page(single_page_config, mpan_mprn)
    puts "#{name} #{mpan_mprn}"
    single_page_config[:charts].each do |chart_name|
      run_chart(mpan_mprn.to_s, chart_name, {meter_definition: mpan_mprn})
    end
  end
end
