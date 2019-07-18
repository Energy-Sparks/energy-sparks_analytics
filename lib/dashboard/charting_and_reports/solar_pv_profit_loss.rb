class SolarPVProfitLoss
  DAYS_IN_YEAR = 365
  SOLAR_FIT = 0.12
  attr_reader :profit_loss_multiple_years

  def initialize(meter_collection, mains_electricity_rate_£_per_kWh = 0.12, fit_£_per_kwh = 0.20, export_£_per_kwh = 0.05)
    @meter_collection = meter_collection
    @mains_electricity_rate_£_per_kWh = mains_electricity_rate_£_per_kWh
    @fit_£_per_kwh = fit_£_per_kwh
    @export_£_per_kwh = export_£_per_kwh
    @profit_loss_multiple_years = calculate_profit_loss_multiple_years
  end

  def annual_electricity_including_onsite_solar_pv_consumption_kwh
    value_from_profit_loss_tables(SolarPVPanels::MAINS_ELECTRICITY_CONSUMPTION_INCLUDING_ONSITE_PV, :kwh)
  end

  def annual_solar_pv_consumed_onsite_kwh
    value_from_profit_loss_tables(SolarPVPanels::SOLAR_PV_ONSITE_ELECTRIC_CONSUMPTION_METER_NAME, :kwh)
  end

  def annual_exported_solar_pv_kwh
    value_from_profit_loss_tables(SolarPVPanels::SOLAR_PV_EXPORTED_ELECTRIC_METER_NAME, :kwh)
  end

  def annual_solar_pv_kwh
    annual_solar_pv_consumed_onsite_kwh + annual_exported_solar_pv_kwh
  end

  def annual_saving_from_solar_pv_percent
    annual_solar_pv_consumed_onsite_kwh / annual_electricity_including_onsite_solar_pv_consumption_kwh
  end

  def annual_carbon_saving_percent
    annual_solar_pv_kwh / annual_electricity_including_onsite_solar_pv_consumption_kwh
  end

  def annual_consumed_from_national_grid_kwh
    annual_electricity_including_onsite_solar_pv_consumption_kwh - annual_solar_pv_consumed_onsite_kwh
  end

  def approx_annual_co2_saving_estimate_kg
    annual_electricity_consumption_co2 = ScalarkWhCO2CostValues.new(@meter_collection).aggregate_value({year: 0}, :electricity, :co2)
    solar_pv_to_consumption_ratio = annual_solar_pv_kwh / annual_electricity_including_onsite_solar_pv_consumption_kwh
    solar_pv_to_consumption_ratio * annual_electricity_consumption_co2
  end

  private def value_from_profit_loss_tables(row_type, data_type)
    data = profit_loss_multiple_years.values[0][:data].detect { |row| row[:name] == row_type }
    data[data_type]
  end

  private def calculate_profit_loss_multiple_years
    results_by_year = {}
    end_date = @meter_collection.aggregated_electricity_meters.amr_data.end_date
    start_date = [end_date - 365, @meter_collection.aggregated_electricity_meters.amr_data.start_date].max
    return nil if end_date - start_date < 365
    while start_date >= @meter_collection.aggregated_electricity_meters.amr_data.start_date
      results_by_year[formatted_date_range(start_date, end_date)] = annual_profit_loss(start_date, end_date)
      start_date -= DAYS_IN_YEAR
      end_date -= DAYS_IN_YEAR
    end
    results_by_year
  end

  private def formatted_date_range(start_date, end_date)
    start_date.strftime('%d %b %Y') + ' to ' + end_date.strftime('%d %b %Y')
  end

  private def annual_profit_loss(start_date, end_date)
    profit_loss = []

    annual_electricity_consumption_kwh = ScalarkWhCO2CostValues.new(@meter_collection).aggregate_value({year: 0}, :electricity, :kwh)
    ann_kwh = @meter_collection.aggregated_electricity_meters.amr_data.kwh_date_range(start_date, end_date, :kwh)

    meters = [@meter_collection.aggregated_electricity_meters] + @meter_collection.aggregated_electricity_meters.sub_meters

    total_pv_kwh = 0.0

    meters.each do |meter|
      next if meter.name == SolarPVPanels::ELECTRIC_CONSUMED_FROM_MAINS_METER_NAME
      kwh = meter.amr_data.kwh_date_range(start_date, end_date, :kwh).magnitude
      profit_loss.push(
        {
          name: meter.name,
          kwh:  kwh,
          rate: rate(meter.name),
          £:    kwh * rate(meter.name)
        }
      )
      pv_meters = [SolarPVPanels::SOLAR_PV_ONSITE_ELECTRIC_CONSUMPTION_METER_NAME, SolarPVPanels::SOLAR_PV_EXPORTED_ELECTRIC_METER_NAME]
      total_pv_kwh += kwh if pv_meters.include?(meter.name)
    end

    profit_loss.push(
      {
        name: 'Solar feed-in-tariff',
        kwh:  total_pv_kwh,
        rate: SOLAR_FIT,
        £:    total_pv_kwh * SOLAR_FIT
      }
    )

    total_kwh = profit_loss.detect { |row| row[:name] == @meter_collection.aggregated_electricity_meters.name }[:kwh]
    total =
      {
        name: 'Total',
        kwh:   total_kwh - total_pv_kwh,
        rate: nil,
        £:    profit_loss.map { |row| row[:£] }.sum # Statsample bug means you can't use sum direct, so map and then sum
      }

    {
      data:   profit_loss,
      total:  total
    }
  end

  private def rate(meter_name)
    case meter_name
    when SolarPVPanels::SOLAR_PV_ONSITE_ELECTRIC_CONSUMPTION_METER_NAME
      BenchmarkMetrics::ELECTRICITY_PRICE
    when SolarPVPanels::SOLAR_PV_EXPORTED_ELECTRIC_METER_NAME
      BenchmarkMetrics::SOLAR_EXPORT_PRICE
    when SolarPVPanels::ELECTRIC_CONSUMED_FROM_MAINS_METER_NAME
      BenchmarkMetrics::ELECTRICITY_PRICE
    else
      -1.0 * BenchmarkMetrics::ELECTRICITY_PRICE
    end
  end
end
