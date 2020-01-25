class RunAdultDashboard < RunCharts

  def run_flat_dashboard(control)
    @all_html = ''
    pages = control.fetch(:pages, page_list)
    pages.each do |page|
      if DashboardConfiguration::ADULT_DASHBOARD_GROUP_CONFIGURATIONS.key?(page)
        definition = DashboardConfiguration::ADULT_DASHBOARD_GROUP_CONFIGURATIONS[page]
        run_one_page(page, definition, control)
      else
        puts "Not running page #{page}"
      end
    end
    save_to_excel
    write_html
  end

  private def page_list
    @school.adult_report_groups.map do |report_group|
      DashboardConfiguration::ADULT_DASHBOARD_GROUPS[report_group]
    end.flatten
  end

  private def excel_variation
    '- adult dashboard'
  end

  private def run_one_page(page, definition, control)
    puts "Running page #{page} has class #{definition.key?(:content_class)}"
    logger.info "Running page #{page} has class #{definition.key?(:content_class)}"

    # ap definition[:content_class].front_end_template_variables # front end variables

    advice = definition[:content_class].new(@school) # , control[:user])

    puts "Page failed, as advice not valid #{page}" unless advice.valid_alert?
    return unless advice.valid_alert?

    advice.calculate

    puts "Page failed 1, as advice not available to users #{page}" unless advice.make_available_to_users?
    # return unless advice.make_available_to_users?

    if advice.has_structured_content?
      puts "Advice has structured content"
      
      advice.structured_content.each do |component_advice|
        puts component_advice[:title]
        puts component_advice[:content].map { |component| component[:type] }.join('; ')
      end
    end
    content = advice.content
        
    @failed_charts.concat(advice.failed_charts) unless advice.failed_charts.empty?

    puts "Page failed 2, as advice not available to users #{page}" unless advice.make_available_to_users?

    comparison = CompareContentResults.new(control, @school.name)
    comparison.save_and_compare_content(page, content)

    html, charts = advice.analytics_split_charts_and_html(content)

    worksheet_name = definition[:content_class].excel_worksheet_name

    @worksheets[worksheet_name] = charts
    @all_html += html.join(' ')
  end

  def write_html
    html_file = HtmlFileWriter.new(@school.name + '- adult dashboard')
    html_file.write_header_footer('', @all_html, nil)
    html_file.close
  end
end
