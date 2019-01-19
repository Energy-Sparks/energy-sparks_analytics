# rubocop:disable Metrics/LineLength, Style/FormatStringToken, Style/FormatString, Lint/UnneededDisable
#
# Alerts: Energy Sparks alerts
#         this is a mix of short-term alerts e.g. your energy consumption has gone up since last week
#         and longer term alerts - energy assessments e.g. your energy consumption at weekends it high
#
# the current code strcucture consists of an alert base class from which individual classes analysing
# different aspect of energy consumption are derived
#
# plus a reporting class for alerts which can return a mixture of text, html, charts etc., although
# much of the potential complexity of this framework will not be implemented in the first iteration
#

class AlertAnalysisBase
  include Logging
  attr_reader :analysis_report

  def initialize(school, report_type)
    @school = school
    @analysis_report = AlertReport.new(report_type)
  end

  def analyse(asof_date)
    begin
      @analysis_report.max_asofdate = maximum_alert_date
      analyse_private(asof_date)
    rescue StandardError => e
      text = "Unexpected Internal Error: please report to hello@energysparks.uk\n"
      text += e.message
      text += e.backtrace.join("\n")
      description1 = AlertDescriptionDetail.new(:text, text)
      @analysis_report.add_detail(description1)
      @analysis_report.status = :failed
    end
  end

  def add_report(report)
    raise EnergySparksUnexpectedStateException.new('add_report now deprecated from AlertAnalysisBase')
  end

  def maximum_alert_date
    raise EnergySparksAbstractBaseClass.new('Error: incorrect attempt to use abstract base class ' + name)
  end

  def self.valid_alerts(school, asof_date)
    valid_alerts = all_available_alerts(school)

    valid_alerts.each do |alert|
      alert.analyse(asof_date)
      results = alert.analysis_report
      puts '=' * 80
      puts results
    end
  end

  def self.analyse_all(school, asof_date)
    valid_alerts = all_available_alerts(school)

    valid_alerts.each do |alert|
      alert.analyse(asof_date)
      results = alert.analysis_report
      puts "\n" * 3
      puts results
    end
  end

  def pupils
    if @school.respond_to?(:number_of_pupils) && @school.number_of_pupils > 0
      @school.number_of_pupils
    elsif @school.respond_to?(:school) && !@school.school.number_of_pupils > 0
      @school.school.number_of_pupils
    else
      throw EnergySparksBadDataException.new('Unable to find number of pupils for alerts')
    end
  end

  def floor_area
    if @school.respond_to?(:floor_area) && !@school.floor_area.nil? && @school.floor_area > 0.0
      @school.floor_area
    elsif @school.respond_to?(:school) && !@school.school.floor_area.nil? && @school.school.floor_area > 0.0
      @school.school.floor_area
    else
      throw EnergySparksBadDataException.new('Unable to find number of floor_area for alerts')
    end
  end

  def school_type
    @school.school_type

    if @school.respond_to?(:school_type) && !@school.school_type.nil?
      @school.school_type.instance_of?(String) ? @school.school_type.to_sym : @school.school_type
    elsif @school.respond_to?(:school) && !@school.school.school_type.nil?
      @school.school.school_type.instance_of?(String) ? @school.school.school_type.to_sym : @school.school.school_type
    else
      throw EnergySparksBadDataException.new("Unable to find number of school_type for alerts #{@school.school_type} #{@school.school.school_type}")
    end
  end

  # returns a list of the last n 'school_days' before and including the asof_date
  def last_n_school_days(asof_date, school_days)
    list_of_school_days = []
    while school_days > 0
      unless @school.holidays.holiday?(asof_date) || asof_date.saturday? || asof_date.sunday?
        list_of_school_days.push(asof_date)
        school_days -= 1
      end
      asof_date -= 1
    end
    list_of_school_days.sort
  end

  private

  def analyse_private(asof_date)
    raise EnergySparksAbstractBaseClass.new('Error: incorrect attempt to use abstract base class')
  end

  def self.all_available_alerts(school)
    alerts = [
      AlertElectricityBaseloadVersusBenchmark.new(school),
      AlertChangeInElectricityBaseloadShortTerm.new(school),
      AlertChangeInDailyElectricityShortTerm.new(school),
      AlertOutOfHoursElectricityUsage.new(school),
      AlertElectricityAnnualVersusBenchmark.new(school),
      AlertGasAnnualVersusBenchmark.new(school),
      AlertOutOfHoursGasUsage.new(school),
      AlertChangeInDailyGasShortTerm.new(school),
      AlertWeekendGasConsumptionShortTerm.new(school),
      AlertImpendingHoliday.new(school),
      AlertHeatingOnOff.new(school),
      AlertHotWaterEfficiency.new(school),
      AlertHeatingComingOnTooEarly.new(school),
      AlertThermostaticControl.new(school)
    ]
  end
end