class RunAdultDashboard < RunCharts

  def run_flat_dashboard(control)
    @all_html = ''
    differing_pages = {}
    pages = control.fetch(:pages, page_list)
    pages.each do |page|
      if DashboardConfiguration::ADULT_DASHBOARD_GROUP_CONFIGURATIONS.key?(page)
        definition = DashboardConfiguration::ADULT_DASHBOARD_GROUP_CONFIGURATIONS[page]
        differences = run_one_page(page, definition, control)
        differing_pages[page] = !differences.nil? && !differences.empty?
      else
        puts "Not running page #{page}"
      end
    end
    save_to_excel
    write_html
    differing_pages
  end

  def self.summarise_differences(differences, _control)
    summarise_school_differences(differences)
    summarise_page_differences(differences)
  end

  private

  def self.summarise_school_differences(differences)
    puts "================Differences By School===================="
    differences.each do |school_name, page_differs|
      diff_count = page_differs.values.count{ |v| v }
      no_diff_count = page_differs.length - diff_count
      puts sprintf('%-30.30s: %3d differ %3d same', school_name, diff_count, no_diff_count)
    end
  end

  def self.summarise_page_differences(differences)
    by_page_type = calculate_page_differences(differences)
    print_page_differences(by_page_type)
  end

  def self.calculate_page_differences(differences)
    by_page_type = {}
    differences.each do |school_name, page_differs|
      page_differs.each do |page_name, differs|
        by_page_type[page_name] ||= {}

        by_page_type[page_name][true]  ||= 0
        by_page_type[page_name][false] ||= 0

        by_page_type[page_name][differs] += 1
      end
    end
    by_page_type
  end

  def self.print_page_differences(by_page_type)
    puts "================Differences By Page Type================="
    by_page_type.each do |page_name, stats|
      puts sprintf('%-30.30s: %3d differ %3d same', page_name, by_page_type[page_name][true], by_page_type[page_name][false])
    end
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
    puts "Running page:   #{page}"
    logger.info "Running page #{page} has class #{definition.key?(:content_class)}"

    # ap definition[:content_class].front_end_template_variables # front end variables

    advice = definition[:content_class].new(@school) # , )

    unless advice.valid_alert?
      puts "                Page failed, as advice not valid #{page}" 
      return
    end

    unless advice.relevance == :relevant
      puts "                Page failed, as advice not relevant #{page}" 
      return
    end

    advice.calculate

    puts "                Page failed 1, as advice not available to users #{page}" unless advice.make_available_to_users?
    return unless advice.make_available_to_users?

    if advice.has_structured_content?
      begin
        # puts "Advice has structured content"
        # puts "Has #{advice.structured_content.length} components and is called #{advice.class.name}"
        
        advice.structured_content.each do |component_advice|
          # puts component_advice[:title]
          # puts component_advice[:content].map { |component| component[:type] }.join('; ')
        end
      rescue NoMethodError => e
        puts e
        puts "To DO Remove this code after fixing issue when have more time PH 15Oct2020"
        return
      end
    end
    content = advice.content(user_type: control[:user])
    fe_content = advice.front_end_content(user_type: control[:user])
        
    @failed_charts.concat(advice.failed_charts) unless advice.failed_charts.empty?

    puts "                Page failed 2, as advice not available to users #{page}" unless advice.make_available_to_users?

    comparison = CompareContentResults.new(control, @school.name)
    differences = comparison.save_and_compare_content(page, content, true)

    html, charts = advice.analytics_split_charts_and_html(content)

    worksheet_name = definition[:content_class].excel_worksheet_name

    @worksheets[worksheet_name] = charts
    @all_html += html.join(' ')
    differences
  end

  def write_html
    html_file = HtmlFileWriter.new(@school.name + '- adult dashboard')
    html_file.write_header_footer('', @all_html, nil)
    html_file.close
  end
end
