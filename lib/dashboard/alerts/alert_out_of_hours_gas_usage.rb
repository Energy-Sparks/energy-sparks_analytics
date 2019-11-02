#======================== Gas: Out of hours usage =============================
require_relative 'alert_out_of_hours_base_usage.rb'

class AlertOutOfHoursGasUsage < AlertOutOfHoursBaseUsage
  attr_reader :daytype_breakdown_table
  def initialize(school, fuel = 'gas', oo_percent = BenchmarkMetrics::PERCENT_GAS_OUT_OF_HOURS_BENCHMARK,
          fuel_price = BenchmarkMetrics::GAS_PRICE, type = :gasoutofhours,
          bookmark = 'GasOutOfHours', meter_defn_not_used = :allheat,
          good_out_of_hours_use_percent = 0.3, bad_out_of_hours_use_percent = 0.7)
    super(school, fuel, oo_percent,
          fuel_price, type, bookmark, meter_defn_not_used,
          good_out_of_hours_use_percent, bad_out_of_hours_use_percent)
  end

  protected def aggregate_meter
    @school.aggregated_heat_meters
  end

  def maximum_alert_date
    aggregate_meter.amr_data.end_date
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
