class N3rgyToEnergySparksTariffs
  class UnexpectedNon24HourRangeForFlatRate < StandardError; end
  class UnexpectedWeekdays < StandardError; end

  def initialize(n3rgy_parameterised_tariff)
    @n3rgy_parameterised_tariff = n3rgy_parameterised_tariff
  end

  def convert
    return nil if @n3rgy_parameterised_tariff.nil?

    { accounting_tariff_generic:  embed_standing_charges_in_rates }
  end

  private

  # N3rgy returns independent schedules of kwh rates and standing charges
  # Energy Sparks by default groups them, so the kw rates and standing
  # charges apply for the same date ranges
  def embed_standing_charges_in_rates
    one_or_more = @n3rgy_parameterised_tariff[:kwh_rates] # weekday tariffs are arrays of rates
    kwh_rates = one_or_more.is_a?(Hash) ? [one_or_more] : one_or_more
    kwh_rates.map do |kwh_rate|
      kwh_rate.map do |kwh_date_range, kwh_rate|
        standing_charges = standing_charges_for_date_range(kwh_date_range)
        standing_charges.map { |sc| merge_tariffs(sc, kwh_date_range, kwh_rate) }
      end.flatten
    end.flatten
  end

  def merge_tariffs(standing_charge, kwh_date_range, kwh_rate)
    overlap_dates = intersect_overlapping_date_ranges(standing_charge.keys.first, kwh_date_range)
    tariff = {
      start_date:       overlap_dates.first,
      end_date:         overlap_dates.last,
      name:             'Tariff from DCC SMETS2 meter',
    }
    tariff.merge(convert_rates(kwh_rate, standing_charge.values.first))
  end

  def standing_charges_for_date_range(kwh_date_range)
    @n3rgy_parameterised_tariff[:standing_charges].map do |standing_charge_date_range, standing_charge|
      dri = intersect_dateranges(standing_charge_date_range, kwh_date_range)
      dri.nil? ? nil : { dri => { per: :day, rate: standing_charge }}
    end.compact
  end

  def convert_rates(rates, standing_charge)
    if rates.length == 1
      raise UnexpectedNon24HourRangeForFlatRate, "time of day range  #{rates.keys.first} doesnt cover 24 hours" unless whole_24_hours?(rates.keys.first)
      {
        rates: {
          flat_rate: {
            per:    :kwh,
            rate:   rates.values.first
          },
          standing_charge: standing_charge
        },
        type: :flat_rate,
        source: :dcc
      }
    else
      type = rates.values.any?{ |v| v.is_a?(Hash) } ? :differential_tiered : :differential
      converted_rates = rates.map.with_index do |(time_of_day_range, rate), index|
        unless time_of_day_range.is_a?(Symbol) && time_of_day_range == :weekdays
          base = {
            from:   time_of_day_range.first,
            to:     time_of_day_range.last,
            per:    :kwh,
          }

          if rate.is_a?(Float)
            [
              "rate#{index}".to_sym,
              base.merge({ rate:   rate })
            ]
          else
            [
              "tiered_rate#{index}".to_sym,
              base.merge(convert_tiered_rate(rate))
            ]
          end
        end
      end.compact.to_h

      config = {
        rates:  converted_rates.merge({standing_charge: standing_charge}),
        type:   type,
        source: :dcc
      }

      set_weekdays(rates, config)

      config
    end
  end

  def set_weekdays(rates, config)
    if rates.key?(:weekdays)
      config[:sub_type] = :weekday_weekend

      if !([1, 2, 3, 4, 5] & rates[:weekdays]).empty?
        config[:weekday] = true
      elsif !([0, 6] & rates[:weekdays]).empty?
        config[:weekend] = true
      else
        raise UnexpectedWeekdays, "Unexepected weekdays #{rate}"
      end
    end
  end

  def convert_tiered_rate(rates)
    rates.map.with_index do |(threshold_range, rate), index|
      [
        "tier#{index}".to_sym,
        {
          low_threshold:  threshold_range.first,
          high_threshold: threshold_range.last, # overlap with low of next tier, match to high of lower tier first
          rate:           rate
        }
      ]
    end.to_h
  end

  def whole_24_hours?(time_of_day_range)
    time_of_day_range.first == TimeOfDay30mins.new( 0,  0) &&
    time_of_day_range.last  == TimeOfDay30mins.new(23, 30)
  end

  def intersect_dateranges(dr1, dr2)
    if dr1.last < dr2.first || dr1.first > dr2.last
      nil
    else
      intersect_overlapping_date_ranges(dr1, dr2)
    end
  end

  def intersect_overlapping_date_ranges(dr1, dr2)
    [dr1.first, dr2.first].max..[dr1.last, dr2.last].min
  end
end
