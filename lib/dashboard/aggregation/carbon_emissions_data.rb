

class CarbonEmissions < HalfHourlyData
  attr_reader :flat_type, :flat_rate, :meter_id
  def initialize(meter_id_for_debug, amr_data, flat_rate, grid_carbon_schedule)
    super(:amr_data_carbon_emissions)
    @meter_id = meter_id_for_debug
    calculate_carbon_emissions(amr_data, flat_rate, grid_carbon_schedule)
  end

  # either flat_rate or grid_carbon is set, the other to nil
  private def calculate_carbon_emissions(amr_data, flat_rate, grid_carbon)
    (amr_data.start_date..amr_data.end_date).each do |date|
      emissions = nil
      if flat_rate.nil?
        emissions = AMRData.fast_multiply_x48_x_x48(amr_data.days_kwh_x48(date, :kwh), grid_carbon.one_days_data_x48(date))
      else
        emissions = AMRData.fast_multiply_x48_x_scalar(amr_data.days_kwh_x48(date, :kwh), flat_rate)
      end
      add(date, emissions)
    end
    total_emissions = total_in_period(start_date, end_date) / 1_000.0
    rate_type = flat_rate.nil? ? 'grid schedule' : 'flat rate'
    info = "Created carbon emissions for meter #{meter_id}, #{self.length} days from #{start_date} to #{end_date}, #{total_emissions.round(0)} tonnes CO2 emissions, using #{rate_type}"
    logger.info info
  end
end
