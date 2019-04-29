#======================== Holiday Alert =======================================
require_relative 'alert_analysis_base.rb'
require_relative 'alert_out_of_hours_electricity_usage.rb'

class AlertImpendingHoliday < AlertGasOnlyBase
  WEEKDAYS_HOLIDAY_LOOKAHEAD_PERIOD = 5

  attr_reader :saving_kwh

  def initialize(school)
    super(school, :impendingholiday)
  end

  def self.template_variables
    specific = {'Impending holiday' => TEMPLATE_VARIABLES}
    specific.merge!({"Impending Holiday (additonal)" => third_party_alert_variables})
    specific.merge!(self.superclass.template_variables)
    specific
  end

  def timescale
    'week'
  end

  TEMPLATE_VARIABLES = {
    saving_kwh: {
      description: 'Upcoming holiday',
      units:  {kwh: :gas}
    },
  }

  ALERT_INHERITANCE = { # name_var_name: { class, old_name }
    electricity_schoolday_open_kwh: { class_type: AlertOutOfHoursElectricityUsage, variable_name: :schoolday_open_kwh }
  }

  def self.third_party_alert_variables
    vars = {}
    ALERT_INHERITANCE.each do |new_variable_name, third_party_alert_variable|
      third_party_alert = third_party_alert_variable[:class_type]
      variable_definition = third_party_alert.flatten_front_end_template_variables[third_party_alert_variable[:variable_name]]
      puts "assigning #{new_variable_name} to #{variable_definition} from #{third_party_alert_variable[:variable_name]}"
      vars[new_variable_name] = variable_definition
    end
    vars
  end

  private def assign_third_party_alert_variables(third_party_alert)
    ALERT_INHERITANCE.each do |new_variable_name, third_party_alert_variable|
      self.class.send(:attr_reader, new_variable_name)
      instance_variable_set('@' + new_variable_name.to_s, third_party_alert.send(third_party_alert_variable[:variable_name]))
    end
  end

  private def calculate(asof_date)
    # annual gas holiday kWh, £: above frost protection, versus benchmark, versus % of annual usage, turning heating off, turning hot water off
    # annual electricity kWh: above baseload, versus benchmark, versus % of annual usage
    # previous year's holiday of same type; excess cost
    # tips:
    # - freezer consolidation, off
    # - reduce baseload

    electric_out_of_hours = AlertOutOfHoursElectricityUsage.new(@school)
    electric_out_of_hours.calculate(nil)
    assign_third_party_alert_variables(electric_out_of_hours)

    @saving_kwh = electricity_schoolday_open_kwh

    @rating = 5.0
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