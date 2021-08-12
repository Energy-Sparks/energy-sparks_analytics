require_relative './fitting_base.rb'
class GasEstimationBase < TargetingAndTrackingFittingBase
  class EnoughGas < StandardError; end
  class MoreDataAlreadyThanEstimate < StandardError; end
  class UnexpectedAbstractBaseClassRequest < StandardError; end
  include Logging

  def initialize(meter, annual_kwh, target_dates)
    super(meter.amr_data, meter.meter_collection.holidays)
    @meter = meter
    @annual_kwh = annual_kwh#
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

  def scaled_day(date, scale, profile_x48)
    days_x48 = AMRData.fast_multiply_x48_x_scalar(profile_x48, scale)
    OneDayAMRReading.new(@meter.mpan_mprn, date, 'TARG', nil, DateTime.now, days_x48)
  end

  def add_scaled_days_kwh(date, scale, profile_x48)
    one_days_reading = scaled_day(date, scale, profile_x48)
    add_day(date, one_days_reading)
  end

  def add_day(date, one_days_reading)
    one_year_amr_data.add(date, one_days_reading)
  end

  def calculate_holey_amr_data_total_kwh(holey_data)
    total = 0.0
    (holey_data.start_date..holey_data.end_date).each do |date|
      total += holey_data.one_day_total(date) if holey_data.date_exists?(date)
    end
    total
  end
end
