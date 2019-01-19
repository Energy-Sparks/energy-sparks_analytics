#======================== Weekend Gas Consumption =============================
# gas shouldn't be consumed at weekends, apart for from frost protection
require_relative 'alert_gas_model_base.rb'

class AlertWeekendGasConsumptionShortTerm < AlertGasModelBase
  MAX_COST = 2.5 # £2.5 limit
  FROST_PROTECTION_TEMPERATURE = 4

  def initialize(school)
    super(school, :weekendgasconsumption)
  end

  def analyse_private(asof_date)
    weekend_dates = previous_weekend_dates(asof_date)
    weekend_kwh = kwh_usage_outside_frost_period(weekend_dates, FROST_PROTECTION_TEMPERATURE)
    weekend_cost = BenchmarkMetrics::GAS_PRICE * weekend_kwh
    usage_text = sprintf('%.0f kWh/£%.0f', weekend_kwh, weekend_cost)

    @analysis_report.term = :shortterm
    @analysis_report.add_book_mark_to_base_url('WeekendGas')

    if weekend_cost > MAX_COST
      @analysis_report.summary = 'Your weekend gas consumption was more than expected'
      text = 'Your weekend gas consumption was more than expected at ' + usage_text
      description1 = AlertDescriptionDetail.new(:text, text)
      @analysis_report.rating = 2.0
      @analysis_report.status = :poor
    else
      @analysis_report.summary = 'Your weekend gas consumption was good'
      text = 'Your weekend gas consumption was ' + usage_text
      description1 = AlertDescriptionDetail.new(:text, text)
      @analysis_report.rating = 10.0
      @analysis_report.status = :good
    end
    @analysis_report.add_detail(description1)
  end

  def previous_weekend_dates(asof_date)
    weekend_dates = []
    while weekend_dates.length < 2
      if asof_date.saturday? || asof_date.sunday?
        weekend_dates.push(asof_date)
      end
      asof_date -= 1
    end
    weekend_dates.sort
  end

  def kwh_usage_outside_frost_period(dates, frost_protection_temperature)
    total_kwh = 0.0
    dates.each do |date|
      (0..47).each do |halfhour_index|
        if @school.temperatures.temperature(date, halfhour_index) > frost_protection_temperature
          total_kwh += @school.aggregated_heat_meters.amr_data.kwh(date, halfhour_index)
        end
      end
    end
    total_kwh
  end
end