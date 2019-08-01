require_relative './alert_period_comparison_base.rb'

class AlertSchoolWeekComparisonElectricity < AlertPeriodComparisonBase
  def initialize(school, type = :electricitypreviousschoolweekcomparison)
    super(school, type)
  end

  def self.template_variables
    specific = { 'Change in between last 2 school weeks' => dynamic_template_variables(:electricity) }
    specific.merge(superclass.template_variables)
  end

  def fuel_type; :electricity end

  def comparison_chart
    :last_2_school_weeks_electricity_comparison_alert
  end

  def timescale; 'last 2 full school weeks' end

  protected def current_period_name(current_period)
    "last school week (#{current_period.start_date.strftime('%a %d-%m-%Y')} to #{current_period.end_date.strftime('%a %d-%m-%Y')})"
  end

  protected def previous_period_name(previous_period)
    "previous school week (#{previous_period.start_date.strftime('%a %d-%m-%Y')} to #{previous_period.end_date.strftime('%a %d-%m-%Y')})"
  end

  protected def last_two_periods(asof_date)
    [school_week(asof_date, 0), school_week(asof_date, -1)]
  end

  private def school_week(asof_date, offset)
    sunday, saturday, _week_count = @school.holidays.nth_school_week(asof_date, offset)
    SchoolDatePeriod.new(:alert, "School Week offset #{offset}", sunday, saturday)
  end
end
