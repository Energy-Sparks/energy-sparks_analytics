class MeterTariff
  attr_reader :tariff
  def initialize(meter, tariff)
    @mpxn  = meter.mpxn
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
  class UnexpectedRateType < StandardError; end

  def initialize(meter, tariff)
    super(meter, tariff)
    check_differential_times(all_times) if differential?(nil)
  end
  
  def differential?(_date)
    tariff[:rates].key?(:nighttime_rate)
  end

  def costs(date, kwh_x48)
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

  def rate_type?(type)
    %i[rate daytime_rate nighttime_rate flat_rate].include?(type)
  end

  def standing_charges(date, days_kwh)
    standing_charge = {}
    tariff[:rates].each do |standing_charge_type, rate|
      next if rate_type?(standing_charge_type)
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
      raise_and_log_error(IncompleteTimeRanges, "Incomplete differential tariff time of day ranges #{@mpxn}", time_ranges)
    end
  end

  def check_overlapping_time_ranges(time_ranges)
    if count_rates_every_half_hour(time_ranges).any?{ |v| v > 1 }
      raise_and_log_error(OverlappingTimeRanges, "Overlapping differential tariff time of day ranges #{@mpxn}", time_ranges)
    end
  end

  def raise_and_log_error(exception, message, data)
    logger.info message
    logger.info data
    # TODO(PH, 4Apr2021) - fix data in database, check upstream code works, then uncomment this code
    # raise exception, message
  end

  def check_time_ranges_on_30_minute_boundaries(time_ranges)
    time_of_days = [time_ranges.map(&:first), time_ranges.map(&:last)].flatten
    if time_of_days.any?{ |tod| !tod.on_30_minute_interval? }
      raise TimeRangesNotOn30MinuteBoundary, "Differential tariff time of day  rates not on 30 minute interval #{@mpxn}"
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
    # TODO(PH, 8Apr2021)
    rate_types.any? { |type| rate_rate_type?(type) || tiered_rate_type?(type) }
  end

  def rate_type?(type)
    super(type) || rate_rate_type?(type) || tiered_rate_type?(type)
  end

  def rate_rate_type?(type)
    type.to_s.match(/^rate[0-9]$/)
  end

  def tiered_rate_type?(type)
    type.to_s.match(/^tiered_rate[0-9]$/)
  end

  def rate?(_date)
    rate_types.any? { |type| type.to_s.match(/^rate[0-9]$/) }
  end

  def tiered?(_date)
    rate_types.any? { |type| type.to_s.match(/^tiered_rate[0-9]$/) }
  end

  def rate_types
    tariff[:rates].keys.select { |type| rate_type?(type) }
  end

  def costs(date, kwh_x48)
    if differential?(date)
      {
        rates_x48: rate_types.map { |type| weighted_costs(kwh_x48, type)}.inject(:merge),
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
      times(type)
    end
  end

  # returns a hash, whereas other parent classes just return the value
  # because a single tier type might return a dffierent sub type for
  # each threshold, so 1 type in but potentially multiple types returned
  def weighted_costs(kwh_x48, type)
    if tiered_rate_type?(type)
      calculate_tiered_costs_x48(type, kwh_x48)
    else
      weights = DateTimeHelper.weighted_x48_vector_single_range(times(type), rate(type))
      cost_x48 = AMRData.fast_multiply_x48_x_x48(weights, kwh_x48)
      { differential_rate_name(type) => cost_x48 }
    end
  end

  def differential_rate_name(type)
    format_time_range(@tariff[:rates][type][:from], @tariff[:rates][type][:to]).to_sym
  end

  def format_time_range(from, to)
    "#{from}_to_#{to}"
  end

  def calculate_tiered_costs_x48(type, kwh_x48)
    costs_x48 = {}

    from_hh_index = @tariff[:rates][type][:from].to_halfhour_index
    to_hh_index   = @tariff[:rates][type][:to].to_halfhour_index

    (from_hh_index..to_hh_index).each do |hh_index|
      rates = tiered_rate(kwh_x48[hh_index], @tariff[:rates][type])
      rates.each do |new_tier_name, cost|
        costs_x48[new_tier_name] ||= AMRData.one_day_zero_kwh_x48 
        costs_x48[new_tier_name][hh_index] = cost
      end
    end
    costs_x48
  end

  # returns a hash with seperate key for each threhold bucket
  def tiered_rate(kwh, rate_config)
    tiers = rate_config.select { |type, config| tiered_rate_sub_type?(type) }

    tiers.map do |tier_name, tier|
      # PH 8Apr2021 - there is an ambiguity on the boundary between 2 thresholds
      #             - which rate is take exactly on the boundary
      kwh_above_threshold_start = kwh - tier[:low_threshold]
      threshold_range = tier[:high_threshold] - tier[:low_threshold]
      kwh_in_threshold = [kwh_above_threshold_start, threshold_range].min
      [
        tier_description(tier_name, tier[:low_threshold], tier[:high_threshold], rate_config),
        tier[:rate] * kwh_in_threshold
      ]
    end.to_h
  end

  def tiered_rate_sub_type?(type)
    type.to_s.match(/tier[0-9]/)
  end

  def tier_description(tier_name, low_threshold, high_threshold, rate_config)
    time_range = format_time_range(rate_config[:from], rate_config[:to])
    threshold_range = threshhold_range_description(tier_name, low_threshold, high_threshold)
    "#{threshold_range}_#{time_range}".to_sym
  end

  def threshhold_range_description(tier_name, low_threshold, high_threshold)
    if high_threshold.infinite?
      "#{tier_name}_above_#{low_threshold.round(0)}_kwh"
    elsif low_threshold.zero?
      "#{tier_name}_below_#{high_threshold.round(0)}_kwh"
    else
      "#{tier_name}_#{low_threshold.round(0)}_to_#{high_threshold.round(0)}_kwh"
    end
  end
end
