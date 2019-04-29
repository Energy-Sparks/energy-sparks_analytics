#======================== Holiday Alert =======================================
require_relative 'alert_analysis_base.rb'
require_relative 'alert_out_of_hours_electricity_usage.rb'
require_relative 'alert_out_of_hours_gas_usage.rb'

class AlertImpendingHoliday < AlertGasOnlyBase
  WEEKDAYS_HOLIDAY_LOOKAHEAD_PERIOD = 15

  attr_reader :saving_kwh, :daytype_breakdown_table, :total_annual_£, :holidays_percent

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
    'week'
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
    meter_fuel_type_availability: {
      description: 'returns meter availability information both electricity and gas or gas only or electricity only, and or storage heaters',
      units:  String
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

    @saving_kwh = electricity_holidays_kwh

    @rating = 5.0
  end

  def gas?; !@school.aggregated_heat_meters.nil? end
  def electricity?; !@school.aggregated_electricity_meters.nil? end

  private def combine_electricity_and_gas_annual_out_of_hours_data
    @total_annual_£ = (electricity? ? electricity_total_annual_£ : 0.0) + (gas? ? gas_total_annual_£ : 0.0)
    @holidays_£         = (electricity? ? electricity_holidays_£ : 0.0) + (gas? ? gas_holidays_£ : 0.0)
    @potential_saving_£ = (electricity? ? electricity_potential_saving_£ : 0.0) + (gas? ? gas_potential_saving_£ : 0.0)
    @holidays_percent = @holidays_£ / @total_annual_£

    aggregate_electricity_and_gas_day_type_breakdown_tables(electricity_daytype_breakdown_table, gas_daytype_breakdown_table)
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

  def maximum_alert_date
    @school.holidays.last.start_date
  end
end