#======================== Gas: Out of hours usage =============================
require_relative 'alert_out_of_hours_base_usage.rb'

class AlertOutOfHoursGasUsage < AlertOutOfHoursBaseUsage
  attr_reader :daytype_breakdown_table
  def initialize(school)
    super(school, 'gas', BenchmarkMetrics::PERCENT_GAS_OUT_OF_HOURS_BENCHMARK,
          BenchmarkMetrics::GAS_PRICE, :gasoutofhours, 'GasOutOfHours', :allheat,
          0.3, 0.7)
  end

  def maximum_alert_date
    @school.aggregated_heat_meters.amr_data.end_date
  end

  def needs_electricity_data?
    false
  end

  def breakdown_chart
    :alert_daytype_breakdown_gas
  end

  def group_by_week_day_type_chart
    :alert_group_by_week_gas
  end

  TEMPLATE_VARIABLES = {
    breakdown_chart: {
      description: 'Pie chart showing out of hour gas consumption breakdown (school day, school day outside hours, weekends, holidays), also used for table generation',
      units:  :chart
    },
    group_by_week_day_type_chart: {
      description: 'Weekly chart showing out of hour electricity consumption breakdown (school day, school day outside hours, weekends, holidays), for last year',
      units:  :chart
    }
  }

  def self.template_variables
    specific = {
      'Gas specific out of hours consumption' => TEMPLATE_VARIABLES,
      'Out of hours energy consumption' => superclass.static_template_variables(:gas)
    }
    specific.merge(superclass.template_variables)
  end
end
