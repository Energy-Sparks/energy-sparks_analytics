class AlertBaseloadBase < AlertElectricityOnlyBase

  def self.baseload_alerts
    [
      AlertElectricityBaseloadVersusBenchmark,
      AlertChangeInElectricityBaseloadShortTerm,
      AlertSeasonalBaseloadVariation,
      AlertIntraweekBaseloadVariation
    ]
  end

  def initialize(school, report_type, meter = school.aggregated_electricity_meters)
    super(school, report_type)
    @report_type = report_type
    @meter = meter
  end

  def calculate_all_baseload_alerts(asof_date)
    baseload_alerts.each do alert_class
      alert = alert_class.new(@school, @report_type, @meter)
      [
        alert,
        valid_calculation(alert, asof_date)
      ]
    end.to_h
  end

  def commentary
    charts_and_html = {}
    charts_and_html.push( { type: :html,  content: '<h3>No device yet</h3>' } )
    charts_and_html.push( { type: :chart_name, content: :electricity_baseload_by_day_of_week } )
    charts_and_html
  end

  private

  def valid_calculation(alert, asof_date)
    return false unless alert.valid_alert?
    alert.analyse(asof_date, true)
    alert.make_available_to_users?
  end
end