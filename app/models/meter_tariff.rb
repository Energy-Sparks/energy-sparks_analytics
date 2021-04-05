class MeterTariff
  attr_reader :tariff
  def initialize(meter, tariff)
    @meter  = meter
    @tariff = tariff
  end

  def default?
    @tariff[:default] == true
  end

  def in_date_range?(date)
    date >= @tariff[:start_date] && date <= @tariff[:end_date]
  end

  def times(type)
    @tariff[:rates][type][:from]..@tariff[:rates][type][:to]
  end

  def rate(type)
    @tariff[:rates][type][:rate]
  end

  def weighted_cost(kwh_x48, type)
    weights = DateTimeHelper.weighted_x48_vector_single_range(times(type), rate(type))
    AMRData.fast_multiply_x48_x_x48(weights, kwh_x48)
  end
end

class EconomicTariff < MeterTariff
end

class AccountingTariff < EconomicTariff
  include Logging
  class OverlappingTimeRanges < StandardError; end
  class IncompleteTimeRanges < StandardError; end
  class TimeRangesNotOn30MinuteBoundary  < StandardError; end
  def initialize(meter, tariff)
    super(meter, tariff)
    check_differential_times(all_times) if differential?(nil)
  end
  class UnexpectedRateType < StandardError; end
  def differential?(_date)
    tariff[:rates].key?(:nighttime_rate)
  end

  def costs(date, kwh_x48)
    differential = 
    if differential?(date)
      {
        rates_x48: {
          nighttime_rate:   weighted_cost(kwh_x48, :nighttime_rate),
          daytime_rate:     weighted_cost(kwh_x48, :daytime_rate),
        },
        standing_charges: standing_charges(date, kwh_x48.sum),
        differential: true
      }
    else
      {
        rates_x48: {
          flat_rate:     AMRData.fast_multiply_x48_x_scalar(kwh_x48, tariff[:rates][:rate][:rate])
        },
        standing_charges: standing_charges(date, kwh_x48.sum),
        differential: false
      }
    end
  end

  def standing_charges(date, days_kwh)
    standing_charge = {}
    tariff[:rates].each do |standing_charge_type, rate|
      next if [:rate, :daytime_rate, :nighttime_rate, :flat_rate].include?(standing_charge_type)
      standing_charge[standing_charge_type] = daily_rate(date, rate[:per], rate[:rate], days_kwh)
    end
    standing_charge
  end

  private

  def all_times
    [times(:nighttime_rate), times(:daytime_rate)]
  end

  def daily_rate(date, per, rate, days_kwh)
    case per
    when :day
      rate
    when :month
      rate / DateTimeHelper.days_in_month(date)
    when :quarter
      rate / DateTimeHelper.days_in_quarter(date)
    when :kwh # treat these as day only rates for the moment TODO(PH, 8Apr2019), should be intraday
      rate * days_kwh
    else
      raise UnexpectedRateType, "Unexpected unit rate type for tariff #{per}"
    end
  end

  def check_differential_times(time_ranges)
    check_time_ranges_on_30_minute_boundaries(time_ranges)
    check_complete_time_ranges(time_ranges)
    check_overlapping_time_ranges(time_ranges)
  end

  def check_complete_time_ranges(time_ranges)
    if count_rates_every_half_hour(time_ranges).any?{ |v| v == 0 }
      raise_and_log_error(IncompleteTimeRanges, "Incomplete differential tariff time of day ranges #{@meter.mpxn}", time_ranges)
    end
  end

  def check_overlapping_time_ranges(time_ranges)
    if count_rates_every_half_hour(time_ranges).any?{ |v| v > 1 }
      raise_and_log_error(OverlappingTimeRanges, "Overlapping differential tariff time of day ranges #{@meter.mpxn}", time_ranges)
    end
  end

  def raise_and_log_error(exception, message, data)
    logger.info message
    logger.info data
    # TODO(PH, 4Apr2021) - fix data in database, check upstream code works
    # raise exception, message
  end

  def check_time_ranges_on_30_minute_boundaries(time_ranges)
    time_of_days = [time_ranges.map(&:first), time_ranges.map(&:last)].flatten
    if time_of_days.any?{ |tod| !tod.on_30_minute_interval? }
      raise TimeRangesNotOn30MinuteBoundary, "Differential tariff time of day  rates not on 30 minute interval #{@meter.mpxn}"
    end
  end

  def count_rates_every_half_hour(time_ranges)
    @count_rates_every_half_hour ||= calculate_rates_every_half_hour(time_ranges)
  end

  def calculate_rates_every_half_hour(time_ranges)
    hh_count = Array.new(48, 0)
    hh_time_ranges = time_ranges.map{ |tr| tr.first.to_halfhour_index..tr.last.to_halfhour_index }
    hh_time_ranges.each do |hh_range|
      hh_range.each do |hh_i|
        if hh_i == 48
          logger.info 'differential tariff end date should really be set to 23:30 not 24:00'
        else
          hh_count[hh_i] += 1
        end
      end
    end
    hh_count
  end
end

class GenericAccountingTariff < AccountingTariff
  def differential?(_date)
    # date needed for weekday/weekend tariffs?
    rate_types.any?{ |type| type.to_s.match(/rate[0-9]/) }
  end

  def costs(date, kwh_x48)
    if differential?(date)
      {
        rates_x48: rate_types.map { |type| [type, weighted_cost(kwh_x48, type)]}.to_h,
        standing_charges: standing_charges(date, kwh_x48.sum)
      }
    else
      {
        rates_x48: {
          flat_rate:     AMRData.fast_multiply_x48_x_scalar(kwh_x48, tariff[:rates][:flat_rate][:rate])
        },
        standing_charges: standing_charges(date, kwh_x48.sum),
        differential: true
      }
    end
  end

  def all_times
    rate_types.map do |type|
      tariff[:rates][:from]..tariff[:rates][:to]
    end
  end

  def rate_types
    tariff[:rates].keys.select?{ |type| type.to_s.match(/rate[0-9]/) }
  end
end
