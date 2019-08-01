#======================== Heating Sensitivity Advice ==============
require_relative 'alert_gas_model_base.rb'

class AlertHotWaterInsulationAdvice < AlertGasModelBase
  attr_reader :annual_hotwater_poor_insulation_heatloss_estimate_kwh
  attr_reader :annual_hotwater_poor_insulation_heatloss_estimate_percent
  attr_reader :annual_hotwater_poor_insulation_heatloss_estimate_£
  attr_reader :hotwater_poor_insulation_heatloss_chart

  def initialize(school)
    super(school, :hotwaterinsulation)
    @relevance = :never_relevant if @relevance != :never_relevant && heating_only # set before calculation
  end

  TEMPLATE_VARIABLES = {
    annual_hotwater_poor_insulation_heatloss_estimate_kwh: {
      description: 'Potential annual loss from poorly insulated hot water system - kwh',
      units: {kwh: :gas}
    },
    annual_hotwater_poor_insulation_heatloss_estimate_£: {
      description: 'Potential annual loss from poorly insulated hot water system - £',
      units:  :£,
    },
    annual_hotwater_poor_insulation_heatloss_estimate_percent: {
      description: 'Potential annual loss from poorly insulated hot water system - percent',
      units:  :percent
    },
    hotwater_poor_insulation_heatloss_chart: {
      description: 'Slope of summer hot water consumption regression line indicates poor insulation',
      units: :chart
    },
    pipework_insulation_cost: {
      description: 'Estimate of cost of insulating pipework',
      units: :£_range
    },
    electric_point_of_use_hotwater_costs: {
      description: 'Estimate of cost of replacing gas hot water system for electric point of use hot water heaters',
      units: :£_range
    }
  }.freeze

  def timescale
    'last year'
  end

  def enough_data
    enough_data_for_model_fit ? :enough : :not_enough
  end

  def self.template_variables
    specific = {'Poorly Insulated Hot Water' => TEMPLATE_VARIABLES}
    specific.merge(self.superclass.template_variables)
  end

  def hotwater_poor_insulation_heatloss_chart
    :thermostatic
  end

  def one_year_saving_£
    x = @annual_hotwater_poor_insulation_heatloss_estimate_£
    Range.new(x * 0.7, x * 1.3)
  end

  def capital_cost
    Range.new(
      [pipework_insulation_cost.first, electric_point_of_use_hotwater_costs.first].min,
      [pipework_insulation_cost.last,  electric_point_of_use_hotwater_costs.last ].max
    )
  end

  def relevance
    @relevant = (aggregate_meter.nil? || heating_only) ? :never_relevant : :relevant
  end

  private def calculate_annual_hotwater_poor_insulation_heatloss_estimate(asof_date)
    start_date = model_start_date(asof_date)
    savings_kwh, savings_percent = 
      heating_model.hot_water_poor_insulation_cost_kwh(start_date, asof_date)
    @annual_hotwater_poor_insulation_heatloss_estimate_£ = savings_kwh * ConvertKwh.scale_unit_from_kwh(:£, :gas)
    @annual_hotwater_poor_insulation_heatloss_estimate_kwh = savings_kwh
    @annual_hotwater_poor_insulation_heatloss_estimate_percent = savings_percent
  end

  def default_content
    %{
      <% if !enough_data %>
        <p>
          There is less than 1 years data - so Energy Sparks is unable to perform this calculation.
        <p>
      <% else %>
        <p>
          Energy Sparks has analysed the sensitivity of your hot water consumption to outside
          temperatures and estimates <%= annual_hotwater_poor_insulation_heatloss_estimate_£ %>
          (<%= annual_hotwater_poor_insulation_heatloss_estimate_kwh %>)
          each year is lost in your hot water system as temperatures get colder
          likely because of poor insulation.
          This is about <%= annual_hotwater_poor_insulation_heatloss_estimate_percent %>
          of your annual hot water consumption.
        </p>
      <% end %>
    }.gsub(/^  /, '')
  end

  def default_summary
    %{
      <p>
        <% if !enough_data %>
          There is less than 1 years data - so Energy Sparks is unable to perform this calculation.
        <% else %>
          Advice the on the insulation of your hot water system
        <% end %>
      </p>
    }.gsub(/^  /, '')
  end

  private def calculate(asof_date)
    calculate_model(asof_date)
    calculate_annual_hotwater_poor_insulation_heatloss_estimate(asof_date) if @annual_hotwater_poor_insulation_heatloss_estimate_kwh.nil?
    @rating = ((1.0 - annual_hotwater_poor_insulation_heatloss_estimate_percent) * 10.0).round(0)
    @status = !enough_data ? :fail : (rating > 3.0 ? :good : :bad)
    @term = :longterm
    @bookmark_url = nil
  end

  def analyse_private(asof_date)
    calculate(asof_date)

    @analysis_report.term = term
    @analysis_report.status = status
    @analysis_report.rating = rating

    if !enough_data
      @analysis_report.summary = 'Not enough (<1 year) historic gas data to provide advice on hot water insulation losses'
    else
      @analysis_report.summary = 'Advice the insulation of your hot water system'
      text =  'Energy Sparks has analysed the sensitivity of your hot water consumption to outside '
      text += 'temperatures and estimates '
      text += FormatEnergyUnit.format(:£, @annual_hotwater_poor_insulation_heatloss_estimate_£)
      text += '(' + FormatEnergyUnit.format(:kwh, @annual_hotwater_poor_insulation_heatloss_estimate_kwh) + ') '
      text += 'each year is lost in your hot water system as temperatures get colder '
      text += ' likely because of poor insulation. '
      text += sprintf('This is about %.0f percent of your annual hot water consumption.', @annual_hotwater_poor_insulation_heatloss_estimate_percent * 100.0)
      description1 = AlertDescriptionDetail.new(:text, text)
      @analysis_report.add_detail(description1)
      # @analysis_report = nil
    end
  end
end
