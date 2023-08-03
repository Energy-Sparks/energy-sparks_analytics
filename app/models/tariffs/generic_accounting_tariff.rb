require_relative './meter_tariff'

class GenericAccountingTariff < AccountingTariff
  def initialize(meter, tariff)
    super(meter, tariff)
    remove_climate_change_levy_from_standing_charges
  end

  #TODO should just check the :type of tariff
  def differential?(_date)
    !flat_tariff?(_date)
  end

  #TODO should just check the :type of tariff
  def flat_tariff?(_date)
    rate_types.all? { |type| flat_rate_type?(type) }
  end

  def rate_type?(type)
    super(type) || rate_rate_type?(type) || tiered_rate_type?(type)
  end

  def duos_type?(type)
    type.to_s.match?(/^duos/)
  end

  def tnuos_type?(type)
    type == :tnuos
  end

  def standard_standing_charge_type?(type)
    super(type) && !climate_change_levy_type?(type) && !duos_type?(type)
  end

  def climate_change_levy?
    @climate_change_levy
  end

  def tiered_rate_type?(type)
    type.to_s.match?(/^tiered_rate[0-9]$/)
  end

  #Calculates use the "economic costs" for usage on a specific date
  #Applies the flat or differential rates but ignores all other charges
  def economic_costs(date, kwh_x48)
    c = if flat_tariff?(date)
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
    c.merge!({standing_charges: {}, system_wide: system_wide?, default: default?, tariff: self})
  end

  #Calculate the full economic costs for usage on a specific date
  def costs(date, kwh_x48)
    c = if flat_tariff?(date)
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

    c[:rates_x48].merge!(rate_per_kwh_standing_charges(kwh_x48))

    c[:rates_x48].merge!(climate_change_level_costs(date, kwh_x48)) if climate_change_levy?

    c[:rates_x48].merge!(duos_costs(date, kwh_x48)) if has_duos_charge?

    c.merge!(common_data(date, kwh_x48))

    c.deep_merge!(apply_vat(c)) if vat > 0.0

    c
  end

  #this was private in base class
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
      weights = DateTimeHelper.weighted_x48_vector_fast_inclusive(times(type), rate(nil, type))
      cost_x48 = AMRData.fast_multiply_x48_x_x48(weights, kwh_x48)
      { differential_rate_name(type) => cost_x48 }
    end
  end

  #override this to also check the new attributes which will replace the
  #older setting. Treats site wide and school group tariffs as defaults
  #so school and meter specific tariffs are not defaults
  def default?
    super || defaulted_tariff?
  end

  #override this to also check the new attributes which will replace the
  #older setting
  def system_wide?
    super || tariff[:tariff_holder] == :site_settings
  end

  private

  def defaulted_tariff?
    %i[site_settings school_group].include?(tariff[:tariff_holder])
  end

  def rate_types
    tariff[:rates].keys.select { |type| rate_type?(type) }
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

  def climate_change_levy_type?(type)
    type == :climate_change_levy
  end

  def rate_rate_type?(type)
    type.to_s.match?(/^rate[0-9]$/)
  end

  def has_duos_charge?
    tariff[:rates].keys.any?{ |type| duos_type?(type) }
  end

  def has_tnuos_charge?
    tariff[:rates].keys.any?{ |type| tnuos_type?(type) }
  end

  #TODO: vat is converted into a formatted string in front end, but it could be passed directly
  #as a number
  def vat
    if @tariff.key?(:vat) # required if manually entered, not if from dcc
      @tariff[:vat].to_s.to_f / 100.0
    else
      return 0.0
    end
  end

  def apply_vat(costs)
    # spread standing charge VAT across every half hour
    # so can see as one value in charts and tabular user presentation
    vat_x48 = AMRData.fast_add_x48_x_x48(rates_vat_x48(costs), standing_charge_daily_vat_x48(costs))

    { rates_x48: { vat_description.to_sym => vat_x48 } }
  end

  def standing_charge_daily_vat_x48(costs)
    vat_daily = costs[:standing_charges].values.sum * vat
    AMRData.single_value_kwh_x48(vat_daily / 48.0)
  end

  def rates_vat_x48(costs)
    rates_x48 = AMRData.fast_add_multiple_x48_x_x48(costs[:rates_x48].values)
    AMRData.fast_multiply_x48_x_scalar(rates_x48, vat)
  end

  #reformats value from front end
  def vat_description
    "vat@#{(vat * 100).round(0)}%"
  end

  def duos_costs(date, kwh_x48)
    costs = DUOSCharges.kwhs_x48(@mpxn, date, kwh_x48)

    costs.map do |colour_key, kwh_x48|
      duos_key = "duos_#{colour_key.to_s}".to_sym
      [
        duos_key,
        AMRData.fast_multiply_x48_x_scalar(kwh_x48, tariff[:rates][duos_key])
      ]
    end.to_h
  end

  def tnuos_calculator
    @tnuos_calculator ||= TNUOSCharges.new(@amr_data, @tariff)
  end

  def tnuos_cost(date)
    tnuos_calculator.cost(date, @mpxn)
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

  def check_time_ranges_on_30_minute_boundaries(time_ranges)
    time_of_days = [time_ranges.map(&:first), time_ranges.map(&:last)].flatten
    if time_of_days.any?{ |tod| !tod.on_30_minute_interval? }
      raise_and_log_error(TimeRangesNotOn30MinuteBoundary, "Differential tariff time of day rates not on 30 minute interval #{@mpxn}", time_ranges)
    end
  end

  def check_overlapping_time_ranges(time_ranges)
    if count_rates_every_half_hour(time_ranges).any?{ |v| v > 1 }
      tr_debug = time_ranges_compact_summary(time_ranges)
      raise_and_log_error(OverlappingTimeRanges, "Overlapping differential tariff time of day ranges #{@mpxn}:  #{tr_debug}", time_ranges)
    end
  end

  #unused?
  def rate?(_date)
    rate_types.any? { |type| type.to_s.match?(/^rate[0-9]$/) }
  end

  #unused?
  def tiered?(_date)
    rate_types.any? { |type| type.to_s.match?(/^tiered_rate[0-9]$/) }
  end

  #unused?
  def create_weekday_weekend_type_rates(type, rates)
    rates.map { |r| "#{type}_#{r}".to_sym }
  end

  #unused?
  def weekend_weekday_differential_type?(type)
    type.to_s.match?(/^weekend_rate[0-9]$/) || type.to_s.match?(/^weekday_rate[0-9]$/)
  end
end
