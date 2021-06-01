class MeterTariff
  attr_reader :tariff, :fuel_type
  FLAT_RATE = 'Flat Rate'.freeze
  DAYTIME_RATE = 'Daytime Rate'.freeze
  NIGHTTIME_RATE = 'Nighttime Rate'.freeze
  def initialize(meter, tariff)
    @mpxn       = meter.mpxn
    @fuel_type  = meter.fuel_type
    @tariff     = tariff
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
    # NB old style tariffs have exclusive times
    AMRData.fast_multiply_x48_x_x48(weights, kwh_x48)
  end

  
  def self.format_time_range(rate)
    "#{rate[:from]} to #{rate[:to]}".freeze
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

  def system_wide?
    tariff[:system_wide] == true
  end

  def costs(date, kwh_x48)
    t = if differential?(date)
          {
            rates_x48: {
              MeterTariff::NIGHTTIME_RATE => weighted_cost(kwh_x48, :nighttime_rate),
              MeterTariff::DAYTIME_RATE   => weighted_cost(kwh_x48, :daytime_rate),
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

    t[:rates_x48].merge!(rate_per_kwh_standard_charges(kwh_x48))

    t.merge(common_data(date, kwh_x48))
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

  def standing_charges(date, days_kwh)
    standing_charge = {}
    tariff[:rates].each do |standing_charge_type, rate|
      next if rate_type?(standing_charge_type) || rate[:per] == :kwh
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
    when :kwh 
      raise UnexpectedRateType, 'Unexpected internal error: unit rate type kwh should be handled as x48 rather than scalar'
    else
      raise UnexpectedRateType, "Unexpected unit rate type for tariff #{per}"
    end
  end

  # apply per kWh 'standing charges' per half hour
  def rate_per_kwh_standard_charges(kwh_x48)
    rates = tariff[:rates].select do |standing_charge_type, rate|
      standing_charge_type != :climate_change_levy &&
      !rate_type?(standing_charge_type) &&
      rate[:per] == :kwh
    end

    rates.map do |standing_charge_type, rate|
      [
        standing_charge_type.to_s.humanize,
        AMRData.fast_multiply_x48_x_scalar(kwh_x48, rate[:rate])
      ]
    end.to_h
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
    # TODO(PH, 3May2021) - uncomment once system wide accounting tariffs are released
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
  def initialize(meter, tariff)
    super(meter, tariff)
    remove_climate_change_levy_from_standing_charges
  end

  def differential?(_date)
    !flat_tariff?(_date)
  end

  def flat_tariff?(_date)
    rate_types.all? { |type| flat_rate_type?(type) }
  end

  def rate_type?(type)
    super(type) || rate_rate_type?(type) || tiered_rate_type?(type)
  end

  def rate_rate_type?(type)
    type.to_s.match?(/^rate[0-9]$/)
  end

  def climate_change_levy?
    @climate_change_levy
  end

  def weekend_weekday_differential_type?(type)
    type.to_s.match?(/^weekend_rate[0-9]$/) || type.to_s.match?(/^weekday_rate[0-9]$/)
  end

  def tiered_rate_type?(type)
    type.to_s.match?(/^tiered_rate[0-9]$/)
  end

  def flat_rate_type?(type)
    type == :flat_rate
  end

  def weekend_type?
    tariff.key?(:weekend)
  end

  def weekday_type?
    tariff.key?(:weekday)
  end

  def create_weekday_weekend_type_rates(type, rates)
    rates.map { |r| "#{type}_#{r}".to_sym }
  end

  def rate?(_date)
    rate_types.any? { |type| type.to_s.match?(/^rate[0-9]$/) }
  end

  def tiered?(_date)
    rate_types.any? { |type| type.to_s.match?(/^tiered_rate[0-9]$/) }
  end

  def rate_types
    tariff[:rates].keys.select { |type| rate_type?(type) }
  end

  def costs(date, kwh_x48)
    t = if flat_tariff?(date)
          {
            rates_x48: {
              MeterTariff::FLAT_RATE => AMRData.fast_multiply_x48_x_scalar(kwh_x48, tariff[:rates][:flat_rate][:rate])
            },
            differential: false
          }
        else
          {
            rates_x48: rate_types.map { |type| weighted_costs(kwh_x48, type)}.inject(:merge),
            differential: true
          }
        end

    t[:rates_x48].merge!(rate_per_kwh_standard_charges(kwh_x48))

    t[:rates_x48].merge!(climate_change_level_costs(date, kwh_x48)) if climate_change_levy?

    # ap t[:rates_x48], { limit: 4 } if climate_change_levy?

    t.merge(common_data(date, kwh_x48))
  end

  def all_times
    rate_types.map { |rt| times(rt) }
  end

  # returns a hash, whereas other parent classes just return the value
  # because a single tier type might return a dffierent sub type for
  # each threshold, so 1 type in but potentially multiple types returned
  def weighted_costs(kwh_x48, type)
    if tiered_rate_type?(type)
      calculate_tiered_costs_x48(type, kwh_x48)
    else
      weights = DateTimeHelper.weighted_x48_vector_fast_inclusive(times(type), rate(type))
      cost_x48 = AMRData.fast_multiply_x48_x_x48(weights, kwh_x48)
      { differential_rate_name(type) => cost_x48 }
    end
  end

  def differential_rate_name(type)
    ttr = MeterTariff.format_time_range(@tariff[:rates][type])
    append_weekday_weekend(ttr)
  end

  def append_weekday_weekend(name)
    name += ' (weekends)' if weekend_type?
    name += ' (weekdays)' if weekday_type?
    name
  end

  def remove_climate_change_levy_from_standing_charges
    if @tariff.key?(:climate_change_levy)
      @climate_change_levy = @tariff[:climate_change_levy]
      @tariff.delete(:climate_change_levy)
    else
      @climate_change_levy = false
    end
  end

  def climate_change_level_costs(date, kwh_x48)
    climate_change_levey_key, levy = ClimateChangeLevy.rate(@fuel_type, date)
    {
      climate_change_levey_key => AMRData.fast_multiply_x48_x_scalar(kwh_x48, levy)
    }
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
    tiers = rate_config.select { |type, _config| tiered_rate_sub_type?(type) }

    tiers.map do |tier_name, tier|
      # PH 8Apr2021 - there is an ambiguity on the boundary between 2 thresholds
      #             - which rate is take exactly on the boundary
      kwh_above_threshold_start = kwh - tier[:low_threshold]
      next if kwh_above_threshold_start <= 0.0
      threshold_range = tier[:high_threshold] - tier[:low_threshold]
      kwh_in_threshold = [kwh_above_threshold_start, threshold_range].min
      [
        tier_description(tier_name, tier[:low_threshold], tier[:high_threshold], rate_config),
        tier[:rate] * kwh_in_threshold
      ]
    end.compact.to_h
  end

  def tiered_rate_sub_type?(type)
    type.to_s.match?(/tier[0-9]/)
  end

  def tier_description(tier_name, low_threshold, high_threshold, rate_config)
    time_range = MeterTariff.format_time_range(rate_config)
    threshold_range = threshhold_range_description(tier_name, low_threshold, high_threshold)
    trtr = "#{time_range}: #{threshold_range}"
    append_weekday_weekend(trtr)
  end

  def threshhold_range_description(tier_name, low_threshold, high_threshold)
    if high_threshold.infinite?
      "above #{low_threshold.round(0)} kwh"
    elsif low_threshold.zero?
      "below #{high_threshold.round(0)} kwh"
    else
      "#{low_threshold.round(0)} to #{high_threshold.round(0)} kwh"
    end
  end
end
