require_relative './fitting_base.rb'
class GasEstimationBase < TargetingAndTrackingFittingBase
  class EnoughGas < StandardError; end
  class MoreDataAlreadyThanEstimate < StandardError; end
  class UnexpectedAbstractBaseClassRequest < StandardError; end
  include Logging

  def initialize(meter, annual_kwh)
    super(meter.amr_data, meter.meter_collection.holidays)
    @meter = meter
    @annual_kwh = annual_kwh
    raise MoreDataAlreadyThanEstimate, "amr data total #{@amr_data.total.round(0)} kWh > #{annual_kwh.round(0)}" if @amr_data.total > annual_kwh
    raise EnoughGas, "Unexpected request to fill in missing gas data as > 365 days (#{@amr_data.days})" if @amr_data.days > 365
  end

  def complete_year_amr_data
    raise UnexpectedAbstractBaseClassRequest, "Unexepected call to base class #{self.class.name}"
  end

  private

  def one_year_amr_data
    @one_year_amr_data ||= AMRData.copy_amr_data(@amr_data)
  end

  def start_of_year_date
    @amr_data.end_date - 364
  end

  def heating_model
    @heating_model ||= calculate_heating_model
  end

  def calculate_heating_model
    whole_meter_period = SchoolDatePeriod.new(:available, 'target model', @amr_data.start_date, @amr_data.end_date)
    @meter.heating_model(whole_meter_period)
  end

  def add_scaled_days_kwh(date, scale, profile_x48)
    days_x48 = AMRData.fast_multiply_x48_x_scalar(profile_x48, scale)

    one_days_reading = OneDayAMRReading.new(@meter.mpan_mprn, date, 'TARG', nil, DateTime.now, days_x48)
    one_year_amr_data.add(date, one_days_reading)
  end
end
