class AlertTargetBase < AlertAnalysisBase
  attr_reader :relevance, :summary

  def initialize(school, type = :electricitylongtermtrend)
    super(school, type)
    @relevance = relevance
  end

  def enough_data
    aggregate_meter.enough_amr_data_to_set_target? ? :enough : :not_enough
  end

  def relevance
    (!aggregate_meter.nil? && aggregate_meter.target_set?) ? :relevant : :never_relevant
  end

  def timescale
    'at least 1 year'
  end

  protected def user_numeric_comprehension_level
    :target
  end

  def self.long_term_variables(fuel_type)
    {
      summary: {
        description: 'Percent change to date versus target',
        units: String
      },

      tracking_start_date: {
        description: 'Start of a academic year date for tracking',
        units:  :date
      },
      tracking_end_date: {
        description: 'End of a academic year date for tracking',
        units:  :date
      },
      previous_year_start_date: {
        description: 'Start of previous academic year date for tracking',
        units:  :date
      },
      previous_year_end_date: {
        description: 'End of previous academic year date for tracking',
        units:  :date
      },
      previous_year_kwh: {
        description: 'Previous year (annual) kwh',
        units:  :kwh
      },
      previous_year_co2: {
        description: 'Previous year (annual) co2 in kg',
        units:  :co2
      },
      previous_year_£: {
        description: 'Previous year (annual) £cost',
        units:  :£
      },
      current_year_kwh: {
        description: 'Current year year to date kwh',
        units:  :kwh
      },
      current_year_co2: {
        description: 'Current year year to date co2 in kg',
        units:  :co2
      },
      current_year_£: {
        description: 'Current year year to date £cost',
        units:  :£
      },
      current_year_target_kwh: {
        description: 'Current year target kwh',
        units:  :kwh
      },
      current_year_target_co2: {
        description: 'Current year target co2 in kg',
        units:  :co2
      },
      current_year_target_£: {
        description: 'Current year target £cost',
        units:  :£
      },
      current_year_target_kwh_to_date: {
        description: 'Current year target kwh - up until the latest meter reading',
        units:  :kwh
      },
      current_year_target_co2_to_date: {
        description: 'Current year target co2 in kg - up until the latest meter reading',
        units:  :co2
      },
      current_year_target_£_to_date: {
        description: 'Current year target £cost - up until the latest meter reading',
        units:  :£
      },
      current_year_percent_of_target_absolute: {
        description: 'percent above or below year to date target - absolute always positive (kWh)',
        units:  :relative_percent
      },
      current_year_percent_of_target_adjective: {
        description: 'above or below - year to date target (kWh)',
        units:  String
      },
      current_year_percent_of_target: {
        description: 'percent of target this year to date e.g. 95% (kWh)',
        units:  :percent
      },

      last_4_weeks_start_date: {
        description: 'Start of current 4 weeks',
        units:  :date
      },
      last_4_weeks_end_date: {
        description: 'End of current 4 weeks',
        units:  :date
      },
      last_4_weeks_kwh: {
        description: 'Last 4 weeks kwh',
        units:  :kwh
      },
      last_4_weeks_co2: {
        description: 'Last 4 weeks co2 in kg',
        units:  :co2
      },
      last_4_weeks_£: {
        description: 'Last 4 weeks £cost',
        units:  :£
      },
      last_4_weeks_target_kwh: {
        description: 'Last 4 weeks target kwh',
        units:  :kwh
      },
      last_4_weeks_target_co2: {
        description: 'Last 4 weeks target co2 in kg',
        units:  :co2
      },
      last_4_weeks_target_£: {
        description: 'Last 4 weeks target £cost',
        units:  :£
      },
      last_4_weeks_percent_of_target_absolute: {
        description: 'percent above below last 4 weeks target - absolute always positive (kWh)',
        units:  :relative_percent
      },
      last_4_weeks_percent_of_target_adjective: {
        description: 'above or below - target for last 4 weeks (kWh)',
        units:  String
      },
      last_4_weeks_percent_of_target: {
        description: 'percent of target last 4 weeks e.g. 95% (kWh)',
        units:  :percent
      },

      last_week_kwh: {
        description: 'Last week kwh',
        units:  :kwh
      },
      last_week_co2: {
        description: 'Last week co2 in kg',
        units:  :co2
      },
      last_week_£: {
        description: 'Last week £cost',
        units:  :£
      },
      last_week_target_kwh: {
        description: 'Last week target kwh',
        units:  :kwh
      },
      last_week_target_co2: {
        description: 'Last week target co2 in kg',
        units:  :co2
      },
      last_week_target_£: {
        description: 'Last week target £cost',
        units:  :£
      },
      last_week_percent_of_target_absolute: {
        description: 'percent above below last 4 week (kWh)',
        units:  :relative_percent
      },
      last_week_percent_of_target_adjective: {
        description: 'above or below - target for last week (kWh)',
        units:  String
      },
      last_week_percent_of_target: {
        description: 'percent of target last week e.g. 95% (kWh)',
        units:  :percent
      },

      current_target_percent: {
        description: 'current target today e.g. 95%',
        units:  :percent
      },
      current_target_relative_percent_reduction: {
        description: 'current relative target today e.g. 5% (= 95%)',
        units:  :percent
      },
      average_target_to_date_percent: {
        description: 'weighted average target to date',
        units:  :percent
      },
      target_table: {
        description: 'Table of targets (Date, Percent)',
        units: :table,
        header: ['Start date', 'Target reduction'],
        column_types: [Date, :percent]
      },
      annual_target_chart: {
        description: 'annual non-cumulative actual versus target chart (grouped weekly)',
        units:  :chart
      },
      annual_target_cumulative_chart: {
        description: 'annual cumulative actual versus target chart (grouped weekly)',
        units:  :chart
      },
    }
  end

  def tracking_start_date
    @tracking_start_date ||= target_start_date
  end

  def tracking_end_date
    Date.new(tracking_start_date.year + 1, tracking_start_date.month, 1)
  end

  def last_4_weeks_start_date
    [last_4_weeks_end_date - 27, tracking_start_date].max
  end
  def last_4_weeks_end_date; maximum_alert_date end
  # maybe less than 4 weeks if less than 4 weeks into new academic year month
  def days_in_last_4_weeks; last_4_weeks_end_date - last_4_weeks_start_date + 1 end

  def last_week_start_date
    [last_week_end_date - 7, tracking_start_date].max
  end
  def last_week_end_date; maximum_alert_date end
  # maybe less than 4 weeks if less than 4 weeks into new academic year month
  def days_in_last_week; last_week_end_date - last_week_start_date + 1 end

  def previous_year_start_date; previous_year_end_date - 363 end
  def previous_year_end_date;   tracking_start_date - 1 end

  def previous_year_kwh;        @previous_year_kwh ||= previous_year_total(:kwh) end
  def previous_year_co2;        @previous_year_co2 ||= previous_year_total(:co2) end
  def previous_year_£;          @previous_year_£   ||= previous_year_total(:£) end

  def current_year_kwh;         @current_year_kwh ||= current_year_total(:kwh) end
  def current_year_co2;         @current_year_co2 ||= current_year_total(:co2) end
  def current_year_£;           @current_year_£   ||= current_year_total(:£) end

  def current_year_target_kwh; @current_year_target_kwh ||= current_year_target_total(:kwh) end
  def current_year_target_co2; @current_year_target_co2 ||= current_year_target_total(:co2) end
  def current_year_target_£;   @current_year_target_£   ||= current_year_target_total(:£) end

  def current_year_target_kwh_to_date; @current_year_target_kwh_to_date ||= current_year_target_total_to_date(:kwh) end
  def current_year_target_co2_to_date; @current_year_target_co2_to_date ||= current_year_target_total_to_date(:co2) end
  def current_year_target_£_to_date;   @current_year_target_£_to_date   ||= current_year_target_total_to_date(:£) end

  def current_year_percent_of_target_absolute
    absolute_relative_percent(current_year_target_kwh_to_date, current_year_kwh)
  end

  def current_year_percent_of_target_adjective
    percent_adjective(current_year_target_kwh_to_date, current_year_kwh)
  end

  def current_year_percent_of_target
    percent(current_year_target_kwh_to_date, current_year_target_kwh)
  end

  def last_4_weeks_kwh;         @last_4_weeks_kwh ||= last_4_weeks_total(:kwh) end
  def last_4_weeks_co2;         @last_4_weeks_co2 ||= last_4_weeks_total(:co2) end
  def last_4_weeks_£;           @last_4_weeks_£   ||= last_4_weeks_total(:£) end

  def last_4_weeks_target_kwh; @last_4_weeks_target_kwh ||= last_4_weeks_target_total(:kwh) end
  def last_4_weeks_target_co2; @last_4_weeks_target_co2 ||= last_4_weeks_target_total(:co2) end
  def last_4_weeks_target_£;   @last_4_weeks_target_£   ||= last_4_weeks_target_total(:£) end

  def last_4_weeks_percent_of_target_absolute
    absolute_relative_percent(last_4_weeks_target_kwh, last_4_weeks_kwh)
  end

  def last_4_weeks_percent_of_target_adjective
    percent_adjective(last_4_weeks_target_kwh, last_4_weeks_kwh)
  end

  def last_4_weeks_percent_of_target
    percent(last_4_weeks_target_kwh, last_4_weeks_kwh)
  end

  def last_week_kwh;         @last_week_kwh ||= last_week_total(:kwh) end
  def last_week_co2;         @last_week_co2 ||= last_week_total(:co2) end
  def last_week_£;           @last_week_£   ||= last_week_total(:£) end

  def last_week_target_kwh; @last_week_target_kwh ||= last_week_target_total(:kwh) end
  def last_week_target_co2; @last_week_target_co2 ||= last_week_target_total(:co2) end
  def last_week_target_£;   @last_week_target_£   ||= last_week_target_total(:£) end

  def last_week_percent_of_target_absolute
    absolute_relative_percent(last_week_target_kwh, last_week_kwh)
  end

  def last_week_percent_of_target_adjective
    percent_adjective(last_week_target_kwh, last_week_kwh)
  end

  def last_week_percent_of_target
    percent(last_week_target_kwh, last_week_kwh)
  end

  def current_target_percent
    @target_school.aggregate_meter(fuel_type).target.target(maximum_alert_date)
  end

  def current_target_relative_percent_reduction
    (1.0 - current_target_percent)
  end

  def average_target_to_date_percent
    aggregate_target_meter.target.average_target(tracking_start_date, maximum_alert_date)
  end

  def aggregate_meter_end_date
    aggregate_meter.amr_data.end_date
  end

  def maximum_alert_date
    aggregate_meter.amr_data.end_date
  end

  def target_table
    @target_school.aggregate_meter(fuel_type).target.table
  end

  def annual_target_cumulative_chart
    :targeting_and_tracking_weekly_electricity_1_year_cumulative
  end

  def annual_target_chart
    :alert_targeting_and_tracking_weekly_electricity_1_year
  end

  private def calculate(asof_date)
    @summary = summary_text
    @rating = calculate_rating_from_range(0.95, 1.05, rating_target_percent)
    set_savings_capital_costs_payback(potential_savings_range, nil)
  end
  alias_method :analyse_private, :calculate

  def rating_target_percent
    current_year_percent_of_target
  end

  def summary_text
    "#{FormatEnergyUnit.format(:percent, current_year_percent_of_target_absolute, :text)} #{current_year_percent_of_target_adjective} target"
  end

  def potential_savings_range
    saving = previous_year_£ - current_year_target_£
    saving..saving
  end

  def academic_year
    @academic_year ||= @school.holidays.calculate_academic_year_tolerant_of_missing_data(maximum_alert_date)
  end

  def previous_year_total(datatype)
    total(false, previous_year_start_date, previous_year_end_date, datatype)
  end

  def current_year_total(datatype)
    total(false, tracking_start_date, tracking_end_date, datatype)
  end

  def last_4_weeks_total(datatype)
    total(false, last_4_weeks_start_date, last_4_weeks_end_date, datatype)
  end

  def last_4_weeks_target_total(datatype)
    total(true, last_4_weeks_start_date, last_4_weeks_end_date, datatype)
  end

  def last_week_total(datatype)
    total(false, last_week_start_date, last_week_end_date, datatype)
  end

  def last_week_target_total(datatype)
    total(true, last_week_start_date, last_week_end_date, datatype)
  end

  def current_year_target_total(datatype)
    total(true, tracking_start_date, tracking_end_date, datatype)
  end

  def current_year_target_total_to_date(datatype)
    total(true, tracking_start_date, maximum_alert_date, datatype)
  end

  def target_start_date
    @school.target_school.aggregate_meter(fuel_type).target_start_date(maximum_alert_date)
  end

  def total(use_target, start_date, end_date, datatype)
    begin
      chosen_school = use_target ? @school.target_school : @school
      end_date = [end_date, aggregate_meter_end_date].min
      chosen_school.aggregate_meter(fuel_type).amr_data.kwh_date_range(start_date, end_date, datatype)
    rescue EnergySparksNotEnoughDataException => _e
      nil
    end
  end

  def percent_adjective(base, current)
    relative_percent(base, current) > 0.0 ? 'above' : 'below'
  end

  def absolute_relative_percent(base, current)
    relative_percent(base, current).magnitude
  end

  def percent(base, current)
    return 1.0 if base.nil? || current.nil? || base == current
    return 1.0 if base == 0.0
    current / base
  end

  def relative_percent(base, current)
    return 0.0 if base.nil? || current.nil? || base == current
    return 0.0 if base == 0.0
    (current - base) / base
  end
end

class AlertElectricityTargetAnnual < AlertTargetBase
  def self.template_variables
    specific = { 'Electricity targetting and tracking' => long_term_variables('electricity')}
    specific.merge(self.superclass.template_variables)
  end

  def fuel_type
    :electricity
  end

  def aggregate_meter
    @school.aggregated_electricity_meters
  end

  def aggregate_target_meter
    @school.target_school.aggregated_electricity_meters
  end
end

class AlertElectricityTarget4Week < AlertElectricityTargetAnnual
  def rating_target_percent
    last_4_weeks_percent_of_target
  end
end

class AlertElectricityTarget1Week < AlertElectricityTargetAnnual
  def rating_target_percent
    last_week_percent_of_target
  end
end

class AlertGasTargetAnnual < AlertTargetBase
  def self.template_variables
    specific = { 'Gas targetting and tracking' => long_term_variables('gas')}
    specific.merge(self.superclass.template_variables)
  end

  def fuel_type
    :gas
  end

  def aggregate_meter
    @school.aggregated_heat_meters
  end

  def aggregate_target_meter
    @school.target_school.aggregated_heat_meters
  end
end

class AlertGasTarget4Week < AlertGasTargetAnnual
  def rating_target_percent
    last_4_weeks_percent_of_target
  end
end

class AlertGasTarget1Week < AlertGasTargetAnnual
  def rating_target_percent
    last_week_percent_of_target
  end
end
