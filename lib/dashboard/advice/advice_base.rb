require_rel '../charting_and_reports/content_base.rb'
class AdviceBase < ContentBase

  def calculate
    @rating = nil
    promote_data if self.class.config.key?(:promoted_variables)
  end

  def chart_names
    # config = DashboardConfiguration::DASHBOARD_PAGE_GROUPS[:adult_analysis_page][:sub_pages][2][:sub_pages][0]
    self.class.config[:charts]
  end

  def charts
    chart_results = []
    chart_manager = ChartManager.new(@school)
    chart_names.each do |chart_name|
      chart_results.push(chart_manager.run_standard_chart(chart_name))
    end
    chart_results
  end

  def content
    charts_and_html = []
    charts.each do |chart|
      begin
        charts_and_html.push( { type: :html,  content: chart[:advice_header] } ) if chart.key?(:advice_header)
        charts_and_html.push( { type: :chart, content: chart } )
        charts_and_html.push( { type: :html,  content: chart[:advice_footer] } ) if chart.key?(:advice_footer)
      rescue StandardError => e
        puts e.message
        puts e.backtrace
      end
    end
    charts_and_html
  end

  def self.config
    @@config ||= find_config_recursive(config_base, self)
  end

  def self.template_variables
    { 'Summary' => promote_variables }
  end

  def self.promote_variables
    template_variables = {}
    config[:promoted_variables].each do |alert_class, variables|
      variables.each do |to, from|
        template_variables[to] = find_alert_variable_definition(alert_class.template_variables, from)
      end
    end
    template_variables
  end

  def self.find_alert_variable_definition(variable_groups, find_variable_name)
    variable_groups.each do |_group_name, variable_group|
      return variable_group[find_variable_name] if variable_group.key?(find_variable_name)
    end
  end

  private

  def self.config_base
    DashboardConfiguration::DASHBOARD_PAGE_GROUPS[:adult_analysis_page]
  end

  def self.find_config_recursive(parent_page, search_class)
    if parent_page.is_a?(Hash)
      if parent_page.key?(:sub_pages)
        parent_page[:sub_pages].each do |sub_page|
          config = find_config_recursive(sub_page,  search_class)
          return config if config.is_a?(Hash)
        end
      else
        return parent_page if parent_page.key?(:class) && parent_page[:class] == search_class
      end
    end
  end

  def promote_data
    ap self.class.config
    self.class.config[:promoted_variables].each do |alert_class, variables|
      alert = alert_class.new(@school)
      alert.analyse(alert_asof_date, true)
      variables.each do |to, from|
        create_and_set_attr_reader(to, alert.send(from))
      end
    end
  end

  def alert_asof_date
    aggregate_meter.amr_data.end_date
  end

  private def create_and_set_attr_reader(key, value)
    self.class.send(:attr_reader, key)
    instance_variable_set("@#{key}", value)
  end
end