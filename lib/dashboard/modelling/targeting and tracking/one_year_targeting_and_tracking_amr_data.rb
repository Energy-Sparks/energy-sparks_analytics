# consolidates various adjustments needed to calculate next year's targets
# by 'calculating' underlying AMR data for the last year
# Main adjustments
# - electricity: where less than 1 year's data
#                for COVID lockdown3 where there was a ~20% drop in usage
# - gas:         where there is less than 1 year's data
#
# returns a amr data for meter either the original if no adjustment is necessary
# or adjusted data - going back 1+ year, so next year's target can be calculated
#
class OneYearTargetingAndTrackingAmrData
  class MissingAnnualKwhEstimate < StandardError; end

  def initialize(meter, target_dates)
    @meter = meter
    @target_dates = target_dates
  end

  # returns
  # {
  #   amr_data:             amr data,
  #   percent_real_data:    Float,
  #   adjustments_applied:  text description
  # }
  def last_years_amr_data
    @last_years_amr_data ||= calculate_one_year_historic_synthetic_data
  end

  def annual_kwh_estimate_required?
    # probably unnecessary, to be calculated and marshaled by the front end?
    false
  end

  private

  def calculate_one_year_historic_synthetic_data
    data = calculate_last_years_amr_data
    data[:feedback].merge!(@target_dates.serialised_dates_for_debug)
    data
  end

  def calculate_last_years_amr_data
    case @meter.fuel_type
    when :electricity
      if synthetic_data_calculaton_needed?
        fit_electricity
      elsif seasonal_electricity_covid_adjustment.enough_data?
        seasonal_electricity_covid_adjustment_amr_data
      elsif enough_data?
        enough_data_already
      else
        raise StandardError, 'targeting and tracking electric < 1 year not intergrated yet'
      end
    when :gas, :storage_heater
      if synthetic_data_calculaton_needed?
        missing_gas_estimation.calculate_missing_gas
      else
        enough_data_already
      end
    else
      raise StandardError, "targeting and tracking adjustment for fuel #{@meter.fuel_type} currently not supported"
    end
  end

  def synthetic_data_calculaton_needed?
    !@target_dates.full_years_benchmark_data? &&
    !@target_dates.less_than_1_year_data_bumped_start_date_forward_no_annual_estimate?
  end

  def enough_data?
    @meter.enough_amr_data_to_set_target?
  end

  def enough_data_already
    if @target_dates.less_than_1_year_data_bumped_start_date_forward_no_annual_estimate?
      days = (@target_dates.benchmark_end_date - @target_dates.benchmark_start_date).to_i
      historic_data_info = "#{days} days #{@target_dates.benchmark_start_date} to #{@target_dates.benchmark_end_date}"
      {
        amr_data:             @meter.amr_data,
        feedback: {
          percent_real_data:    1.0,
          adjustments_applied:  "No synthetic calculation: as < 1 year (#{historic_data_info}), no annual estimate but target start date bumped forward",
          rule:                 'Enough but limited data for partial year target so no synthetic data'
        }
      }
    else
      {
        amr_data:             @meter.amr_data,
        feedback: {
          percent_real_data:    1.0,
          adjustments_applied:  "No adjustments necessary as > 1 year data (#{@meter.amr_data.days}) and recent (to #{@meter.amr_data.end_date})",
          rule:                 'Enough data already so no synthetic data'
        }
      }
    end
  end

  def fit_electricity
    raise MissingAnnualKwhEstimate, "No annual kwh estimate attribute set for #{@meter.fuel_type}"
    electric_estimate = MissingElectricityEstimation.new(@meter, @target_dates)
    electric_estimate.complete_year_amr_data
  end

  def seasonal_electricity_covid_adjustment
    @seasonal_electricity_covid_adjustment ||= Covid3rdLockdownElectricityCorrection.new(@meter, @meter.meter_collection.holidays)
  end

  def seasonal_electricity_covid_adjustment_amr_data
    @seasonal_electricity_covid_adjustment_amr_data ||= seasonal_electricity_covid_adjustment.adjusted_amr_data
  end

  def missing_gas_estimation
    raise MissingAnnualKwhEstimate, "No annual kwh estimate attribute set for #{@meter.fuel_type}" if @meter.annual_kwh_estimate.nil?
    @missing_gas_estimation ||= MissingGasEstimation.new(@meter, @meter.annual_kwh_estimate, @target_dates)
  end
end
