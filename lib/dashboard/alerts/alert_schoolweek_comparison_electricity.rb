require_relative './alert_period_comparison_base.rb'

class AlertSchoolWeekComparisonElectricity < AlertPeriodComparisonBase
  attr_reader :current_period_start_short_date, :current_period_end_short_date
  attr_reader :previous_period_start_short_date, :previous_period_end_short_date
  def initialize(school, type = :electricitypreviousschoolweekcomparison)
    super(school, type)
  end

  def self.template_variables
    specific = { 'Change in between last 2 school weeks' => dynamic_template_variables(:electricity) }
    specific2 = { 'School week formatted date variables' => formatted_date_variables }
    specific.merge!(specific2)
    specific.merge(superclass.template_variables)
  end

  def self.formatted_date_variables
    {
      current_period_start_short_date: { description: 'Current period start date',    units:  String },
      current_period_end_short_date:   { description: 'Current period end date',      units:  String },
      previous_period_start_short_date: { description: 'Previous period start date',  units:  String  },
      previous_period_end_short_date:   { description: 'Previous period end date',   units:  String  },
    }
  end

  def fuel_type; :electricity end

  def comparison_chart
    :last_2_school_weeks_electricity_comparison_alert
  end

  def calculate(asof_date)
    super(asof_date)

    puts 'Got here philip'

    date_format = '%e %B'
    @current_period_start_short_date    = format_date(current_period_start_date)
    @current_period_end_short_date      = format_date(current_period_end_date)
    @previous_period_start_short_date   = format_date(previous_period_start_date)
    @previous_period_end_short_date     = format_date(previous_period_end_date)
  end
  alias_method :analyse_private, :calculate

  private def format_date(date)
    date.strftime('%e') + ordinal(date.day) + date.strftime(' %B')
  end

  # copied from Active Support - so don't include dependancy in non-rails code
  private def ordinal(number)
    abs_number = number.to_i.abs

    if (11..13).include?(abs_number % 100)
      "th"
    else
      case abs_number % 10
      when 1; "st"
      when 2; "nd"
      when 3; "rd"
      else    "th"
      end
    end
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
