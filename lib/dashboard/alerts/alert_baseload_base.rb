class AlertBaseloadBase < AlertElectricityOnlyBase
  def initialize(school, report_type, meter = school.aggregated_electricity_meters)
    super(school, report_type)
    @report_type = report_type
    @meter = meter
  end
end