require_rel '../charting_and_reports/content_base.rb'
class AdviceBase < ContentBase
  def initialize(school)
    super(school)
  end

  def enough_data
    :enough
  end

  def valid_alert?
    true
  end

  def analyse(asof_date)
    @asof_date = asof_date
    calculate
  end

  def calculate
    @rating = nil
    promote_data if self.class.config.key?(:promoted_variables)
  end

  # override alerts base class, ignore calculation_worked
  def make_available_to_users?
    result = relevance == :relevant && enough_data == :enough
    logger.info "Alert #{self.class.name} not being made available to users: reason: #{relevance} #{enough_data}" if !result
    result
  end

  def rating
    @rating
  end

  def relevance
    :relevant
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

  def front_end_content
    content.select { |segment| %i[html chart_name title].include?(segment[:type]) }
  end

  def content
    charts_and_html = []

    charts_and_html.push( { type: :analytics_html, content: '<hr>' } )
    charts_and_html.push( { type: :title, content: self.class.config[:name] } )
    charts_and_html.push( { type: :analytics_html, content: "<h2>#{self.class.config[:name]}</h2>" } )
    charts_and_html.push( { type: :analytics_html, content: "<h3>Rating: #{rating}</h3>" } )
    charts_and_html.push( { type: :analytics_html, content: "<h3>Valid: #{valid_alert?}</h3>" } )
    charts_and_html.push( { type: :analytics_html, content: "<h3>Make available to users: #{make_available_to_users?}</h3>" } )
    charts_and_html.push( { type: :analytics_html, content: template_data_html } )

    charts.each do |chart|
      begin
        charts_and_html.push( { type: :html,  content: chart[:advice_header] } ) if chart.key?(:advice_header)
        charts_and_html.push( { type: :chart_name, content: chart[:config_name] } )
        charts_and_html.push( { type: :chart, content: chart } )
        charts_and_html.push( { type: :analytics_html, content: "<h3>Chart: #{chart[:config_name]}</h3>" } )
        charts_and_html.push( { type: :html,  content: chart[:advice_footer] } ) if chart.key?(:advice_footer)
      rescue StandardError => e
        puts e.message
        puts e.backtrace
      end
    end
    charts_and_html
  end

  def analytics_split_charts_and_html(content_data)
    html_bits = content_data.select { |h| %i[html analytics_html].include?(h[:type]) }
    html = html_bits.map { |v| v[:content] }
    charts_bits = content_data.select { |h| h[:type] == :chart }
    charts = charts_bits.map { |v| v[:content] }
    [html, charts]
  end

  def self.config
    definition
  end

  def self.excel_worksheet_name
    definition[:excel_worksheet_name]
  end

  private_class_method def self.definition
    DashboardConfiguration::ADULT_DASHBOARD_GROUP_CONFIGURATIONS.select { |_key, defn| defn[:content_class] == self }.values[0]
  end

  def self.template_variables
    { 'Summary' => promote_variables }
  end

  def self.promote_variables
    template_variables = {}
    self.config[:promoted_variables].each do |alert_class, variables|
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

  def promote_data
    self.class.config[:promoted_variables].each do |alert_class, variables|
      alert = alert_class.new(@school)
      alert.analyse(alert_asof_date, true)
      variables.each do |to, from|
        create_and_set_attr_reader(to, alert.send(from))
      end
    end
  end

  def alert_asof_date
    @asof_date ||= aggregate_meter.amr_data.end_date
  end

  def template_data_html
    rows = html_template_variables.to_a
    HtmlTableFormatting.new(['Variable','Value'], rows).html
  end

  private def create_and_set_attr_reader(key, value)
    self.class.send(:attr_reader, key)
    instance_variable_set("@#{key}", value)
  end
end