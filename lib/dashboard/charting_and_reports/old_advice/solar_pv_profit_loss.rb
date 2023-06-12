class SolarPVProfitLoss
  DAYS_IN_YEAR = 365
  SOLAR_FIT = 0.12

  def initialize(meter_collection, mains_electricity_rate_£_per_kWh = 0.15, fit_£_per_kwh = 0.20, export_£_per_kwh = 0.05)
    @meter_collection = meter_collection
    @mains_electricity_rate_£_per_kWh = mains_electricity_rate_£_per_kWh
    @fit_£_per_kwh = fit_£_per_kwh
    @export_£_per_kwh = export_£_per_kwh
  end

  def annual_electricity_including_onsite_solar_pv_consumption_kwh
    last_years_kwh(@meter_collection.aggregated_electricity_meters)[:kwh]
  end

  def annual_solar_pv_consumed_onsite_kwh
    last_years_kwh(sub_meter(:self_consume))[:kwh]
  end

  def period_available_description
    last_years_kwh(sub_meter(:self_consume))[:period_description]
  end

  def annual_exported_solar_pv_kwh
    last_years_kwh(sub_meter(:export))[:kwh]
  end

  def sub_meter(meter_type)
    @meter_collection.aggregated_electricity_meters.sub_meters[meter_type]
  end

  def annual_solar_pv_kwh
    #report using data from the generation meter, rather than adding up the other
    #figures. This aligns this class with what the charts and the change in
    #solar pv benchmark use
    #annual_solar_pv_consumed_onsite_kwh + annual_exported_solar_pv_kwh
    last_years_kwh(sub_meter(:generation))[:kwh]
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

  def annual_co2_saving_kg
    last_years_kwh(sub_meter(:generation))[:co2]
  end

  private

  def sub_meter(meter_type)
    @meter_collection.aggregated_electricity_meters.sub_meters[meter_type]
  end

  private def last_years_kwh(meter)
    @last_years_kwh_cache ||= {}
    @last_years_kwh_cache[meter.name] ||= calculate_years_kwh(meter)
  end

  private def calculate_years_kwh(meter)
    end_date = meter.amr_data.end_date
    start_date = [end_date - 365, meter.amr_data.start_date].max
    days = end_date - start_date + 1

    kwh = meter.amr_data.kwh_date_range(start_date, end_date, :kwh)
    co2 = meter.amr_data.kwh_date_range(start_date, end_date, :co2)

    {
      start_date:             start_date,
      end_date:               end_date,
      kwh:                    kwh.magnitude,
      days:                   days,
      co2:                    co2.magnitude,
      period_description:     FormatEnergyUnit.format(:years, days / 365.0, :text)
    }
  end

  private def period_description(days)
    if days >= 364 - 15
      'last year'
    else
    end
  end

  private def value_from_profit_loss_tables_deprecated(row_type, data_type)
    data = profit_loss_multiple_years.values[0][:data].detect { |row| row[:name].include?(row_type) }
    data[data_type]
  end

  private def profit_loss_multiple_years_deprecated
    @profit_loss_multiple_years_deprecated ||= calculate_profit_loss_multiple_years_deprecated
  end

  private def calculate_profit_loss_multiple_years_deprecated
    results_by_year = {}
    end_date = @meter_collection.aggregated_electricity_meters.amr_data.end_date
    start_date = [end_date - 365, @meter_collection.aggregated_electricity_meters.amr_data.start_date].max
    return nil if end_date - start_date < 365
    while start_date >= @meter_collection.aggregated_electricity_meters.amr_data.start_date
      results_by_year[formatted_date_range(start_date, end_date)] = annual_profit_loss_deprecated(start_date, end_date)
      start_date -= DAYS_IN_YEAR
      end_date -= DAYS_IN_YEAR
    end
    results_by_year
  end

  private def formatted_date_range(start_date, end_date)
    start_date.strftime('%d %b %Y') + ' to ' + end_date.strftime('%d %b %Y')
  end

  private def annual_profit_loss_deprecated(start_date, end_date)
    profit_loss = []

    meters = [@meter_collection.aggregated_electricity_meters] + @meter_collection.aggregated_electricity_meters.sub_meters.values

    total_pv_kwh = 0.0

    meters.each do |meter|
      next if meter.name == SolarPVPanels::ELECTRIC_CONSUMED_FROM_MAINS_METER_NAME
      next unless SolarPVPanels::SUBMETER_TYPES.include?(meter.name) # no storage heaters

      kwh = meter.amr_data.kwh_date_range(start_date, end_date, :kwh).magnitude

      profit_loss.push(
        {
          name: meter.name,
          kwh:  kwh,
          rate: rate_deprecated(meter, start_date, end_date),
          £:    kwh * rate_deprecated(meter.name)
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

  private def rate_deprecated(meter_name)
    case meter_name
    when SolarPVPanels::SOLAR_PV_ONSITE_ELECTRIC_CONSUMPTION_METER_NAME
      BenchmarkMetrics.pricing.electricity_price  # deprecated
    when SolarPVPanels::SOLAR_PV_EXPORTED_ELECTRIC_METER_NAME
      BenchmarkMetrics.pricing.solar_export_price  # deprecated
    when SolarPVPanels::ELECTRIC_CONSUMED_FROM_MAINS_METER_NAME
      BenchmarkMetrics.pricing.electricity_price  # deprecated
    else
      -1.0 * BenchmarkMetrics.pricing.electricity_price  # deprecated
    end
  end
end
