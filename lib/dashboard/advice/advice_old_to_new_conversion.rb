module MeterlessMixin
  def enough_data;      :enough   end
  def rating;           5.0       end
  def relevance;        :relevant end
  def check_relevance;  relevance end
  def self.template_variables
    { 'Summary' => { summary: { description: 'CO2 data', units: String } } }
  end
end

# converts old specialised advice to new content based advice to maintain
# backwards compatibility in short term
class AdviceStructuredOldToNewConversion < AdviceBase
  include MeterlessMixin

  def initialize(school)
    super(school)
    promote_data if self.class.config.key?(:promoted_variables)
  end

  def has_structured_content?(user_type: nil)
    true
  end

  def structured_content(user_type: nil)
    content_information = []
    component_pages.each do |component_page_class|
      component_page = component_page_class.new(@school)
      content_information.push(
        {
          title:    component_page.summary,
          content:  component_page.content
        }
      ) if component_page.relevance == :relevant
    end
    content_information
  end

  def content(user_type: nil)
    content_info = structured_content.map { |component| component[:content] }.flatten
    remove_diagnostics_from_html(content_info, user_type)
  end

  def summary
    @summary ||= summary_text
  end

  def alert_asof_date
    [@school.aggregated_electricity_meters, @school.aggregated_heat_meters].compact.map { |meter| meter.amr_data.end_date }.min
  end

  def enough_data
    max_period_days > 364 ? :enough : :not_enough
  end

  private

  def min_data
    [@school.aggregated_electricity_meters, @school.aggregated_heat_meters].compact.map { |meter| meter.amr_data.start_date }.max
  end

  def max_period_days
    (alert_asof_date - min_data + 1).to_i
  end

  def timescale
    { up_to_a_year: 0 }
  end

  def timescale_description
    FormatEnergyUnit.format(:years, [max_period_days / 365.0, 1.0].min, :html)
  end
end

class AdviceOldToNewConversion < AdviceBase
  include MeterlessMixin
  def initialize(school)
    super(school)
    @content_data = []
    @content_list = []
  end

  def default_accordian_state; :closed end

  def create_class(old_advice_class)
    old_advice_class.new(@school, nil, nil, nil)
  end

  def content(user_type: nil)
    charts_and_html = []
    @content_list.each do |component|
      charts_and_html.push( { type: component[:type], content: component[:content] } )
    end
    @content_data.each do |content|
      begin
        advice_class = create_class(content[:advice_class])
        charts_and_html.push(
          case content[:type]
          when :text
            { type: :html,  content: advice_class.erb_bind(content[:data]) }
          when :function
            { type: :html,  content: advice_class.send(content[:data]) }
          when :chart, :chart_and_text
            components = content.key?(:components) ? content[:components] : [true, true, true]
            chart = run_chart(content[:data])
            if chart.nil?
              nil
            else
              info = []
              info.push({ type: :html,          content: chart[:advice_header]  }) if content[:type] == :chart_and_text && components[0]
              info.push({ type: :chart,         content: chart                  }) if components[1]
              info.push({ type: :chart_name,    content: chart[:config_name]    }) if components[1]
#              info.push({ type: :analytics_html,content: "<p><b>Chart inserted here: #{chart[:config_name]}</b></p>"}) if components[1]
              info.push({ type: :html,          content: chart[:advice_footer]  }) if content[:type] == :chart_and_text && components[2]
              info
            end
          end
        )
      rescue EnergySparksNotEnoughDataException => e
        { type: :chart, html: 'Unfortunately we don\'t have enough meter data to provide this information.' }
      end
    end
    remove_diagnostics_from_html(charts_and_html.compact.flatten, user_type)
  end
end