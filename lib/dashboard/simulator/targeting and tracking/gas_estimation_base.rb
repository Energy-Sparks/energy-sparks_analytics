require_relative './fitting_base.rb'
class GasEstimationBase < TargetingAndTrackingFittingBase
  class EnoughGas < StandardError; end
  class MoreDataAlreadyThanEstimate < StandardError; end
  class UnexpectedAbstractBaseClassRequest < StandardError; end
  include Logging

  def initialize(meter, annual_kwh, target_dates)
    super(meter.amr_data, meter.meter_collection.holidays)
    @meter = meter
    @annual_kwh = annual_kwh
    @target_dates = target_dates
    raise MoreDataAlreadyThanEstimate, "amr data total #{@amr_data.total.round(0)} kWh > #{annual_kwh.round(0)}" if @amr_data.total > annual_kwh
    raise EnoughGas, "Unexpected request to fill in missing gas data as > 365 days (#{@amr_data.days})" if @amr_data.days > 365
  end

  def complete_year_amr_data
    raise UnexpectedAbstractBaseClassRequest, "Unexpected call to base class #{self.class.name}"
  end

  private

  def one_year_amr_data
    @one_year_amr_data ||= AMRData.copy_amr_data(@amr_data, @target_dates.benchmark_start_date, @target_dates.benchmark_end_date)
  end

  def heating_model
    @heating_model ||= calculate_heating_model
  end

  def calculate_heating_model
    benchmark_period = SchoolDatePeriod.new(:available, 'target model', @target_dates.benchmark_start_date, @target_dates.benchmark_end_date)
    @meter.heating_model(benchmark_period)
  end

  def full_heating_model
    @full_heating_model ||= calculate_full_heating_model
  end

  def calculate_full_heating_model
    original_meter_period = SchoolDatePeriod.new(:available, 'target model', @target_dates.original_meter_start_date, @target_dates.original_meter_end_date)
    @meter.heating_model(original_meter_period)
  end
end
