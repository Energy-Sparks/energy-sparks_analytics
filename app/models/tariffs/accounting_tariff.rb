require_relative './meter_tariff'

class AccountingTariff < EconomicTariff
  include Logging
  class OverlappingTimeRanges < StandardError; end
  class IncompleteTimeRanges < StandardError; end
  class TimeRangesNotOn30MinuteBoundary  < StandardError; end
  class UnexpectedRateType < StandardError; end

  def initialize(meter, tariff)
    super(meter, tariff)
    check_differential_times(all_times) if differential?(nil)
  end

  def differential?(_date)
    tariff[:rates].key?(:nighttime_rate)
  end

  def system_wide?
    tariff[:system_wide] == true
  end

  def costs(date, kwh_x48)
    t = if differential?(date)
          {
            rates_x48: {
              MeterTariff::NIGHTTIME_RATE => weighted_cost(date, kwh_x48, :nighttime_rate),
              MeterTariff::DAYTIME_RATE   => weighted_cost(date, kwh_x48, :daytime_rate),
            },
            differential: true
          }
        else
          {
            rates_x48: {
              MeterTariff::FLAT_RATE => AMRData.fast_multiply_x48_x_scalar(kwh_x48, tariff[:rates][:rate][:rate])
            },
            differential: false
          }
        end

    t[:rates_x48].merge!(rate_per_kwh_standing_charges(kwh_x48))

    t.merge!(common_data(date, kwh_x48))
    OneDaysCostData.new(t)
  end

  def common_data(date, kwh_x48)
    {
      standing_charges: standing_charges(date, kwh_x48.sum),
      system_wide:      system_wide?,
      default:          default?,
      tariff:           self
    }
  end

  def rate_type?(type)
    %i[rate daytime_rate nighttime_rate flat_rate].include?(type)
  end

  def tiered_rate_type?(_type)
    false
  end

  def duos_type?(type)
    false
  end

  def tnuos_type?(type)
    false
  end

  def availability_type?(type)
    %i[agreed_availability_charge excess_availability_charge].include?(type)
  end

  # non per kWh standing charges
  def standing_charges(date, days_kwh)
    standing_charge = {}
    tariff[:rates].each do |standing_charge_type, rate|
      if tnuos_type?(standing_charge_type) && rate == true
        standing_charge[standing_charge_type] = tnuos_cost(date)
      elsif standard_standing_charge_type?(standing_charge_type) && rate[:per] != :kwh
        dr = daily_rate(date, rate[:per], rate[:rate], days_kwh, standing_charge_type)
        standing_charge[standing_charge_type] = dr unless dr.nil?
      end
    end
    standing_charge
  end

  private

  def all_times
    [times(:nighttime_rate), times(:daytime_rate)]
  end

  def daily_rate(date, per, rate, days_kwh, type)
    case per
    when :day
      rate
    when :month
      rate / DateTimeHelper.days_in_month(date)
    when :quarter
      rate / DateTimeHelper.days_in_quarter(date)
    when :kva
      if type == :agreed_availability_charge
        agreed_supply_capacity_daily_cost(date)
      elsif type == :excess_availability_charge
        excess_supply_capacity_daily_cost(date)
      else # reactive charges - unknown as not provided by AMR meter feeds, and not passed through DCC yet (June2021)
        0.0
      end
    when :kwh
      raise UnexpectedRateType, 'Unexpected internal error: unit rate type kwh should be handled as x48 rather than scalar'
    else
      raise UnexpectedRateType, "Unexpected unit rate type for tariff #{per}"
    end
  end

  def agreed_supply_capacity_calculator
    @agreed_supply_capacity_calculator ||= AgreedSupplyCapacityCharge.new(@amr_data, @tariff)
  end

  def agreed_supply_capacity_daily_cost(date)
    agreed_supply_capacity_calculator.agreed_supply_capacity_daily_cost(date)
  end

  def excess_supply_capacity_daily_cost(date)
    agreed_supply_capacity_calculator.excess_supply_capacity_daily_cost(date)
  end

  # apply per kWh 'standing charges' per half hour
  def rate_per_kwh_standing_charges(kwh_x48)
    rates = tariff[:rates].select do |standing_charge_type, rate|
      !tnuos_type?(standing_charge_type) &&
      standard_standing_charge_type?(standing_charge_type) &&
      rate[:per] == :kwh
    end

    rates.map do |standing_charge_type, rate|
      [
        standing_charge_type.to_s.humanize,
        AMRData.fast_multiply_x48_x_scalar(kwh_x48, rate[:rate])
      ]
    end.to_h
  end

  def standard_standing_charge_type?(type)
    !rate_type?(type)
  end

  def check_differential_times(time_ranges)
    check_time_ranges_on_30_minute_boundaries(time_ranges)
    check_complete_time_ranges(time_ranges)
    check_overlapping_time_ranges(time_ranges)
  end

  def check_complete_time_ranges(time_ranges)
    if count_rates_every_half_hour(time_ranges).any?{ |v| v == 0 }
      tr_debug = time_ranges_compact_summary(time_ranges)
      raise_and_log_error(IncompleteTimeRanges, "Incomplete differential tariff time of day ranges #{@mpxn}:  #{tr_debug}", time_ranges)
    end
  end

  def check_overlapping_time_ranges(_time_ranges)
  # do nothing, about to be deprecated errors on old accounting tariffs
  end

  def time_ranges_compact_summary(time_ranges)
    time_ranges.map(&:to_s).join(', ')
  end

  def raise_and_log_error(exception, message, data)
    logger.info message
    logger.info data
    raise exception, message
  end

  def check_time_ranges_on_30_minute_boundaries(_time_ranges)
    # do nothing, about to be deprecated errors on old accounting tariffs
  end

  def count_rates_every_half_hour(time_ranges)
    @count_rates_every_half_hour ||= calculate_count_rates_every_half_hour(time_ranges)
  end

  # given multiple time ranges coering a day
  # returns x48 of count of overall time range coverage
  # e.g. 0 value = missing, 2+ = duplicate/overlap
  def calculate_count_rates_every_half_hour(time_ranges)
    tr_masks = time_ranges.map{ |tr| DateTimeHelper.weighted_x48_vector_fast_inclusive(tr, 1) }
    AMRData.fast_add_multiple_x48_x_x48(tr_masks)
  end
end
