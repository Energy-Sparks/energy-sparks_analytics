class RunAdultDashboard < RunCharts

  def run_flat_dashboard(control)
    @all_html = ''
    report_groups = @school.adult_report_groups
    report_groups.each do |report_group|
      DashboardConfiguration::ADULT_DASHBOARD_GROUPS[report_group].each do |page|
        if DashboardConfiguration::ADULT_DASHBOARD_GROUP_CONFIGURATIONS.key?(page)
          definition = DashboardConfiguration::ADULT_DASHBOARD_GROUP_CONFIGURATIONS[page]
          run_one_page(page, definition, control)
        else
          puts "Not running page #{page}"
        end
      end
    end
    save_to_excel
    write_html
  end

  private def excel_variation
    '- adult dashboard'
  end

  private def run_one_page(page, definition, control)
    puts "Running page #{page} has class #{definition.key?(:content_class)}"

    # ap definition[:content_class].front_end_template_variables # front end variables

    advice = definition[:content_class].new(@school)

    advice.calculate

    content = advice.content

    save_content_as_yaml(content)

    html, charts = advice.analytics_split_charts_and_html(content)

    worksheet_name = definition[:content_class].excel_worksheet_name

    @worksheets[worksheet_name] = charts
    @all_html += html.join(' ')
  end

  private def save_content_as_yaml(content)
    filename_base = "adult dashboard content #{@school.name} "
    content.each_with_index do |content_component, n|
      file_name_detail = "#{n} #{content_component[:type]}"
      full_filename = filename_base + file_name_detail + '.yaml'
      puts full_filename
    end
  end

  def write_html
    html_file = HtmlFileWriter.new(@school.name + '- adult dashboard')
    html_file.write_header_footer('', @all_html, nil)
    html_file.close
  end
end
