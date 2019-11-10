class AlertLongTermTrend < AlertAnalysisBase
  attr_reader :this_year_£, :last_year_£, :year_change_£
  attr_reader :percent_change_£, :summary, :prefix

  def initialize(school)
    super(school, :electricitylongtermtrend)
    @relevance == :relevant
  end

  def enough_data
    aggregate_meter.amr_data.days_valid_data > 2 * 365 ? :enough : :not_enough # 365 not 364 to be safe
  end

  def self.long_term_variables(fuel_type)
    {
      this_year_£: {
        description: "This years #{fuel_type} consumption £",
        units:  :£
      },
      last_year_£: {
        description: "Last years #{fuel_type} consumption £",
        units:  :£
      },
      year_change_£: {
        description: "Change between this year\'s and last year\'s #{fuel_type} consumption £",
        units:  :£
      },
      percent_change_£: {
        description: "Change between this year\'s and last year\'s #{fuel_type} consumption %",
        units:  :relative_percent
      },
      summary: {
        description: 'Change in £spend, relative to previous year',
        units: String
      },
      prefix: {
        description: 'Change: up or down',
        units: String
      }
    }
  end

  def maximum_alert_date
    aggregate_meter.amr_data.end_date
  end

  private def calculate(asof_date)
    scalar = ScalarkWhCO2CostValues.new(@school)
    @this_year_£        = scalar.aggregate_value({ year: 0 },  fuel_type, :£)
    @last_year_£        = scalar.aggregate_value({ year: -1 }, fuel_type, :£)
    @year_change_£      = @this_year_£ - @last_year_£
    @percent_change_£   = @year_change_£ / @last_year_£
    @prefix = @year_change_£ > 0 ? 'up' : 'down'
    @summary            = summary_text

    @rating = calculate_rating_from_range(-0.1, 0.15, percent_change_£)

    set_savings_capital_costs_payback(Range.new(year_change_£, year_change_£), nil)
  end
  alias_method :analyse_private, :calculate

  def summary_text
    @prefix + ' ' +
    FormatEnergyUnit.format(:£, @year_change_£, :text) + 'pa since last year, ' +
    FormatEnergyUnit.format(:relative_percent, @percent_change_£, :text)
  end
end

class AlertElectricityLongTermTrend < AlertLongTermTrend
  def self.template_variables
    specific = { 'Electricity long term trend' => long_term_variables('electricity')}
    specific.merge(self.superclass.template_variables)
  end

  def fuel_type
    :electricity
  end

  def aggregate_meter
    @school.aggregated_electricity_meters
  end
end

class AlertGasLongTermTrend < AlertLongTermTrend
  def self.template_variables
    specific = { 'Gas long term trend' => long_term_variables('gas')}
    specific.merge(self.superclass.template_variables)
  end

  def fuel_type
    :gas
  end

  def aggregate_meter
    @school.aggregated_heat_meters
  end
end
