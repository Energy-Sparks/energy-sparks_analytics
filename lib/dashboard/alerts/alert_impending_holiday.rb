#======================== Holiday Alert =======================================
require_relative 'alert_analysis_base.rb'
require_relative 'alert_out_of_hours_electricity_usage.rb'
require_relative 'alert_out_of_hours_gas_usage.rb'

class AlertImpendingHoliday < AlertGasOnlyBase
  WEEKDAYS_HOLIDAY_LOOKAHEAD_PERIOD = 15

  attr_reader :saving_kwh, :daytype_breakdown_table, :total_annual_£, :holidays_percent
  attr_reader :holiday_short_name, :holiday_long_name, :holiday_length_days
  attr_reader :holiday_length_weekdays, :holiday_length_weeks
  attr_reader :holiday_start_date, :holiday_end_date, :holiday_start_date_doy
  attr_reader :last_year_holiday_gas_kwh, :last_year_holiday_gas_£
  attr_reader :last_year_holiday_electricity_kwh, :last_year_holiday_electricity_£
  attr_reader :last_year_holiday_energy_costs_£

  def initialize(school)
    super(school, :impendingholiday)
  end

  def self.template_variables
    specific = { 'Impending holiday' => TEMPLATE_VARIABLES }
    specific['Impending Holiday (additional)'] = third_party_alert_variable_definitions
    specific.merge!(superclass.template_variables)
    specific
  end

  def timescale
    "#{@holiday_length_weeks} week" + (@holiday_length_weeks > 1 ? 's' : '')
  end

  TEMPLATE_VARIABLES = {
    saving_kwh: {
      description: 'Upcoming holiday',
      units:  { kwh: :gas }
    },
    total_annual_£: {
      description: 'Combined annual gas and electricity consumption (£, for available meters)',
      units:  :£
    },
    holidays_percent: {
      description: 'Holidays as a percent of total annual energy cost',
      units:  :percent
    },
    holiday_short_name: {
      description: 'Short name for holiday',
      units:  String
    },
    holiday_long_name: {
      description: 'Short name for holiday, includes year, start, end date',
      units:  String
    },
    holiday_length_days: {
      description: 'Number of days holiday',
      units:  Integer
    },
    holiday_length_weekdays:  {
      description: 'Number of week days in holiday',
      units:  Integer
    },
    holiday_length_weeks: {
      description: 'Number of weeks holiday (rounded up if >= 3 days in week)',
      units:  Integer
    },
    holiday_start_date: {
      description: 'Holiday start date',
      units:  Date
    },
    holiday_end_date: {
      description: 'Holiday end date',
      units:  Date
    },
    holiday_start_date_doy: {
      description: 'Holiday first day - name e.g. Saturday',
      units:  String
    },
    meter_fuel_type_availability: {
      description: 'returns meter availability information both electricity and gas or gas only or electricity only, and or storage heaters',
      units:  String
    },
    last_year_holiday_gas_kwh: {
      description: 'Gas consumption (kWh) in corresponding holiday last year',
      units:  { kwh: :gas }
    },
    last_year_holiday_gas_£: {
      description: 'Gas consumption (£) in corresponding holiday last year',
      units:  :£
    },
    last_year_holiday_electricity_kwh: {
      description: 'Electricity consumption (kWh) in corresponding holiday last year',
      units:  { kwh: :electricity }
    },
    last_year_holiday_electricity_£: {
      description: 'Electricity consumption (£) in corresponding holiday last year',
      units:  :£
    },
    last_year_holiday_energy_costs_£: {
      description: 'Gas plus electricity cost (£) in corresponding holiday last year',
      units:  :£
    },
    daytype_breakdown_table: {
      description: 'Table broken down by school day in/out hours, weekends, holidays - percent in £ terms, £ (annual)',
      units: :table,
      header: [ 'Day type', 'Percent', '£' ],
      column_types: [String, :percent, :£ ]
    },
  }

  ALERT_INHERITANCE = { # name_var_name: { class, old_name }, definition of attributes moved from other alerts, renamed to avoid clashes
    electricity_holidays_kwh:             { class_type: AlertOutOfHoursElectricityUsage, variable_name: :holidays_kwh },
    electricity_total_annual_kwh:         { class_type: AlertOutOfHoursElectricityUsage, variable_name: :total_annual_kwh },
    electricity_holidays_percent:         { class_type: AlertOutOfHoursElectricityUsage, variable_name: :holidays_percent },
    electricity_holidays_£:               { class_type: AlertOutOfHoursElectricityUsage, variable_name: :holidays_£ },
    electricity_total_annual_£:           { class_type: AlertOutOfHoursElectricityUsage, variable_name: :total_annual_£ },
    electricity_potential_saving_kwh:     { class_type: AlertOutOfHoursElectricityUsage, variable_name: :potential_saving_kwh },
    electricity_potential_saving_£:       { class_type: AlertOutOfHoursElectricityUsage, variable_name: :potential_saving_£ },
    electricity_daytype_breakdown_table:  { class_type: AlertOutOfHoursElectricityUsage, variable_name: :daytype_breakdown_table },
    electricity_breakdown_chart:          { class_type: AlertOutOfHoursElectricityUsage, variable_name: :breakdown_chart },
    electricity_weekly_chart:             { class_type: AlertOutOfHoursElectricityUsage, variable_name: :group_by_week_day_type_chart },

    gas_holidays_kwh:             { class_type: AlertOutOfHoursGasUsage, variable_name: :holidays_kwh },
    gas_total_annual_kwh:         { class_type: AlertOutOfHoursGasUsage, variable_name: :total_annual_kwh },
    gas_holidays_percent:         { class_type: AlertOutOfHoursGasUsage, variable_name: :holidays_percent },
    gas_holidays_£:               { class_type: AlertOutOfHoursGasUsage, variable_name: :holidays_£ },
    gas_total_annual_£:           { class_type: AlertOutOfHoursGasUsage, variable_name: :total_annual_£ },
    gas_potential_saving_kwh:     { class_type: AlertOutOfHoursGasUsage, variable_name: :potential_saving_kwh },
    gas_potential_saving_£:       { class_type: AlertOutOfHoursGasUsage, variable_name: :potential_saving_£ },
    gas_daytype_breakdown_table:  { class_type: AlertOutOfHoursGasUsage, variable_name: :daytype_breakdown_table },
    gas_breakdown_chart:          { class_type: AlertOutOfHoursGasUsage, variable_name: :breakdown_chart },
    gas_weekly_chart:             { class_type: AlertOutOfHoursGasUsage, variable_name: :group_by_week_day_type_chart }
  }.freeze

  def self.third_party_alert_variable_definitions
    vars = {}
    ALERT_INHERITANCE.each do |new_variable_name, third_party_alert_variable|
      third_party_alert = third_party_alert_variable[:class_type]
      variable_definition = third_party_alert.flatten_front_end_template_variables[third_party_alert_variable[:variable_name]]
      vars[new_variable_name] = variable_definition
    end
    vars
  end

  private def assign_third_party_alert_variables(class_type, third_party_alert)
    ALERT_INHERITANCE.each do |new_variable_name, third_party_alert_variable|
      if class_type == third_party_alert_variable[:class_type]
        self.class.send(:attr_reader, new_variable_name)
        instance_variable_set('@' + new_variable_name.to_s, third_party_alert.send(third_party_alert_variable[:variable_name]))
      end
    end
  end

  private def merge_in_relevant_third_party_alert_data(alert_type)
    alert = alert_type.new(@school)
    alert.calculate(nil)
    assign_third_party_alert_variables(alert_type, alert)
  end

  private def calculate(asof_date)
    # annual gas holiday kWh, £: above frost protection, versus benchmark, versus % of annual usage, turning heating off, turning hot water off
    # annual gas kWh: above baseload, versus benchmark, versus % of annual usage
    # previous year's holiday of same type; excess cost
    # tips:
    # - freezer consolidation, off
    # - reduce baseload

    merge_in_relevant_third_party_alert_data(AlertOutOfHoursElectricityUsage) if electricity?
    merge_in_relevant_third_party_alert_data(AlertOutOfHoursGasUsage) if gas?

    combine_electricity_and_gas_annual_out_of_hours_data

    holiday_information = upcoming_holiday_information(asof_date)
    @holiday_period = holiday_information[:period]
    set_holiday_variables(holiday_information)
    last_year_holiday = same_holiday_previous_year(@holiday_period)
    set_last_year_holiday_consumption_variables(last_year_holiday.start_date, last_year_holiday.end_date)

    @saving_kwh = electricity_holidays_kwh

    @rating = 5.0
  end

  private def set_last_year_holiday_consumption_variables(start_date, end_date)
    @last_year_holiday_gas_kwh, @last_year_holiday_gas_£ =
      consumption_in_holiday_period(gas?, @school.aggregated_heat_meters, start_date, end_date)
    @last_year_holiday_electricity_kwh, @last_year_holiday_electricity_£ =
      consumption_in_holiday_period(electricity?, @school.aggregated_electricity_meters, start_date, end_date)

    @last_year_holiday_energy_costs_£ = nil_to_zero(@last_year_holiday_gas_£) + nil_to_zero(@last_year_holiday_electricity_£)
  end

  # written for Bishop Sutton where the electricity data is 2 years out of date
  private def nil_to_zero(value)
    value.nil? ? 0.0 : value
  end

  private def consumption_in_holiday_period(set, meter, start_date, end_date)
    return [0.0, 0.0] unless set
    [
      kwh_date_range(meter, start_date, end_date, :kwh),
      kwh_date_range(meter, start_date, end_date, :economic_cost)
    ]
  end



  private def set_holiday_variables(holiday_information)
    @holiday_short_name       = holiday_information[:short_name]
    @holiday_long_name        = holiday_information[:long_name]
    @holiday_type             = holiday_information[:type]
    @holiday_length_days      = holiday_information[:length_days]
    @holiday_length_weeks     = holiday_information[:length_weeks]
    @holiday_mid_date         = holiday_information[:mid_date]
    @holiday_length_weekdays  = holiday_information[:weekdays]
    @holiday_start_date       = holiday_information[:start_date]
    @holiday_end_date         = holiday_information[:end_date]
    @holiday_start_date_doy   = holiday_information[:start_date].strftime('%A')
  end

  def gas?; !@school.aggregated_heat_meters.nil? end
  def electricity?; !@school.aggregated_electricity_meters.nil? end

  private def combine_electricity_and_gas_annual_out_of_hours_data
    @total_annual_£ = (electricity? ? electricity_total_annual_£ : 0.0) + (gas? ? gas_total_annual_£ : 0.0)
    @holidays_£         = (electricity? ? electricity_holidays_£ : 0.0) + (gas? ? gas_holidays_£ : 0.0)
    @potential_saving_£ = (electricity? ? electricity_potential_saving_£ : 0.0) + (gas? ? gas_potential_saving_£ : 0.0)
    @holidays_percent = @holidays_£ / @total_annual_£

    merge_day_type_breakdown_tables(electricity_daytype_breakdown_table, gas_daytype_breakdown_table)
  end

  private def merge_day_type_breakdown_tables(electric_table, gas_table)
    if electricity? && gas?
      aggregate_electricity_and_gas_day_type_breakdown_tables(electric_table, gas_table)
    elsif electricity?
      strip_kwh_from_table(electric_table)
    else
      strip_kwh_from_table(gas_table)
    end
  end

  private def meter_fuel_type_availability
    if electricity? && gas?
      'both electricity and gas' + (@school.storage_heaters? ? '(or storage heater electricity)' : '')
    elsif electricity?
      'electricity only'
    else
      'gas only'
    end
  end

  private def aggregate_electricity_and_gas_day_type_breakdown_tables(electric_table, gas_table)
    @daytype_breakdown_table = []
    electric_table.each_with_index do |electric_row, row_index|
      total_£_for_day_type = electric_row[3] + gas_table[row_index][3]
      @daytype_breakdown_table.push(
        [
          electric_row[0], # day type string
          # skip kWh (secondary energy, can only combine primary, so not additive in kWh)
          total_£_for_day_type / @total_annual_£,
          total_£_for_day_type
        ]
      )
    end
  end

  private def strip_kwh_from_table(table)
    @daytype_breakdown_table = []
    table.each do |row|
      @daytype_breakdown_table.push([row[0], row[2], row[3]])
    end
  end

  def analyse_private(asof_date)
    calculate(asof_date)
    @analysis_report.add_book_mark_to_base_url('UpcomingHoliday')
    @analysis_report.term = :shortterm

    if !@school.holidays.holiday?(asof_date) && upcoming_holiday?(asof_date, WEEKDAYS_HOLIDAY_LOOKAHEAD_PERIOD)
      @analysis_report.summary = 'There is an upcoming holiday - please turn heating, hot water and appliances off'
      text = 'There is a holiday coming up '
      text += 'please ensure all unnecessary appliances are switched off, '
      text += 'including heating and hot water (but remember to flush when turned back on)'
      @analysis_report.rating = 2.0
      @analysis_report.status = :poor
    else
      @analysis_report.summary = 'There is no upcoming holiday, no action needs to be taken'
      text = ''
      @analysis_report.rating = 10.0
      @analysis_report.status = :good
    end

    description1 = AlertDescriptionDetail.new(:text, text)
    @analysis_report.add_detail(description1)
  end

  def upcoming_holiday?(asof_date, num_days)
    asof_date += 1
    while num_days > 0
      unless asof_date.saturday? || asof_date.sunday?
        num_days -= 1
        return true if @school.holidays.holiday?(asof_date)
      end
      asof_date += 1
    end
    false
  end

  private def upcoming_holiday_information(asof_date)
    holiday_period = @school.holidays.find_next_holiday(asof_date)
    length_days = (holiday_period.days + 1).to_i
    weekdays = week_days(holiday_period.start_date, holiday_period.end_date)
    mid_date = holiday_period.start_date + (length_days / 2).floor
    {
      short_name:   determine_holiday_short_name(holiday_period.title),
      long_name:    holiday_period.to_s,
      type:         @school.holidays.type(mid_date),
      length_days:  length_days,
      weekdays:     weekdays,
      length_weeks: (weekdays / 5).floor + ((weekdays % 5) >= 3 ? 1 : 0),# round up if 5 residual
      mid_date:     mid_date,
      start_date:   holiday_period.start_date,
      end_date:     holiday_period.end_date,
      period:       holiday_period
    }
  end

  private def same_holiday_previous_year(holiday_period)
    @school.holidays.same_holiday_previous_year(holiday_period)
  end

  private def week_days(start_date, end_date)
    (end_date - start_date + 1 - weekend_days(start_date, end_date)).to_i
  end

  private def weekend_days(start_date, end_date)
    count = 0
    (start_date..end_date).each do |date|
      count += 1 if weekend?(date)
    end
    count
  end

  private def determine_holiday_short_name(holiday_title)
    holiday_title.gsub(/\s+2\d{3,3}/,'')
  end

  def maximum_alert_date
    @school.holidays.last.start_date
  end
end