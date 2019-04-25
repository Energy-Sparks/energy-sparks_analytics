require_relative './cost_carbon_base'
# holds and calculates a schedule of carbon emissions - matches amd_data so [date] = [48x carbon emissions]

class CarbonEmissions < CostCarbonCalculatedCachedBase
  attr_reader :grid_carbon_schedule, :flat_rate, :meter_id, :amr_data
  def initialize(meter_id_for_debug, parameterised = false, flat_rate = nil, grid_carbon_schedule = nil, amr_data = nil)
    super(:amr_data_carbon_emissions, parameterised)
    @meter_id = meter_id_for_debug
    @flat_rate = flat_rate
    @grid_carbon_schedule = grid_carbon_schedule
    @amr_data = amr_data
  end

  def self.create_carbon_emissions(meter_id_for_debug, amr_data, flat_rate, grid_carbon_schedule, parameterised = false)
    if parameterised
      carbon_emissions = CarbonEmissions.new(meter_id_for_debug, true, flat_rate, grid_carbon_schedule, amr_data)
      carbon_emissions
    else
      carbon_emissions = CarbonEmissions.new(meter_id_for_debug)
      carbon_emissions.calculate_carbon_emissions(amr_data, flat_rate, grid_carbon_schedule)
      carbon_emissions
    end
  end

  # has to be done using data not from parameterised calculation
  def self.combine_carbon_emissions_from_multiple_meters(combined_meter_id, list_of_meters, combined_start_date, combined_end_date)
    Logging.logger.info "Combining carbon emissions from  #{list_of_meters.length} meters from #{combined_start_date} to #{combined_end_date}"
    combined_carbon_emissions = CarbonEmissions.new(combined_meter_id)
    (combined_start_date..combined_end_date).each do |date|
      list_of_meters_on_date = list_of_meters.select { |meter| date >= meter.amr_data.start_date && date <= meter.amr_data.end_date }
      list_of_days_carbon_emissions = list_of_meters_on_date.map { |meter| meter.amr_data.carbon_emissions.one_days_data_x48(date) }
      combined_days_carbon_emissions_x48 = AMRData.fast_add_multiple_x48_x_x48(list_of_days_carbon_emissions)
      combined_carbon_emissions.add(date, combined_days_carbon_emissions_x48)
    end
    Logging.logger.info "Created combined meter emissions #{combined_carbon_emissions.emissions_summary}"
    combined_carbon_emissions
  end

  # either flat_rate or grid_carbon is set, the other to nil
  def calculate_carbon_emissions(amr_data, flat_rate, grid_carbon)
    (amr_data.start_date..amr_data.end_date).each do |date|
      add(date, emissions_for_date(date, amr_data, flat_rate, grid_carbon))
    end
    rate_type = flat_rate.nil? ? 'grid schedule' : 'flat rate'
    logger.info "Created #{emissions_summary} using #{rate_type}"
  end

  private def emissions_for_date(date, amr_data, flat_rate, grid_carbon)
    kwh_x48 = kwh_x48_data_for_date_checked(date, amr_data)
    calculate_emissions_for_date(date, kwh_x48, flat_rate, grid_carbon)
  end

  private def calculate_emissions_for_date(date, kwh_x48, flat_rate, grid_carbon)
    if flat_rate.nil?
      AMRData.fast_multiply_x48_x_x48(kwh_x48, grid_carbon.one_days_data_x48(date))
    else
      AMRData.fast_multiply_x48_x_scalar(kwh_x48, flat_rate)
    end
  end

  private def kwh_x48_data_for_date_checked(date, amr_data)
    if amr_data.date_missing?(date) # TODO(PH, 7Apr2019) - bad Castle data for 1 day in 2009, work out why validation not cleaning up
      logger.warn "Warning: missing amr data for #{date} using zero"
      Array.new(48, 0.0)
    else
      amr_data.days_kwh_x48(date, :kwh)
    end
  end

  def emissions_summary
    total_emissions = total_in_period(start_date, end_date) / 1_000.0
    "carbon emissions for meter #{meter_id}, #{self.length} days from #{start_date} to #{end_date}, #{total_emissions.round(0)} tonnes CO2 emissions"
  end
end
