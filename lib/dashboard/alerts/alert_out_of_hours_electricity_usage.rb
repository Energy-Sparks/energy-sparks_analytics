#======================== Electricity: Out of hours usage =====================
require_relative 'alert_out_of_hours_base_usage.rb'

class AlertOutOfHoursElectricityUsage < AlertOutOfHoursBaseUsage
  attr_reader :daytype_breakdown_table
  def initialize(school)
    super(school, 'electricity', BenchmarkMetrics::PERCENT_ELECTRICITY_OUT_OF_HOURS_BENCHMARK,
          BenchmarkMetrics::ELECTRICITY_PRICE, :electricityoutofhours, 'ElectricityOutOfHours', :allelectricity,
          0.35, 0.65)
  end

  def maximum_alert_date
    @school.aggregated_electricity_meters.amr_data.end_date
  end

  def needs_gas_data?
    false
  end

  def breakdown_chart
    :alert_daytype_breakdown_electricity
  end

  def group_by_week_day_type_chart
    :alert_group_by_week_electricity
  end

  TEMPLATE_VARIABLES = {
    breakdown_chart: {
      description: 'Pie chart showing out of hour electricity consumption breakdown (school day, school day outside hours, weekends, holidays), also used for table generation',
      units:  :chart
    },
    group_by_week_day_type_chart: {
      description: 'Weekly chart showing out of hour electricity consumption breakdown (school day, school day outside hours, weekends, holidays), for last year',
      units:  :chart
    }
  }

  def self.template_variables
    specific = {
      'Electricity specific out of hours consumption' => TEMPLATE_VARIABLES,
      'Out of hours energy consumption' => superclass.static_template_variables(:electricity)
    }
    specific.merge(superclass.template_variables)
  end
end