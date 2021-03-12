class N3rgyToEnergySparksTariffs
  class UnexpectedNon24HourRangeForFlatRate < StandardError; end

  def initialize(n3rgy_parameterised_tariff)
    @n3rgy_parameterised_tariff = n3rgy_parameterised_tariff
  end

  def convert
    return nil if @n3rgy_parameterised_tariff.nil?

    {
      accounting_tariffs:  embed_standing_charges_in_rates
    }
  end

  private

  # N3rgy returns independent schedules of kwh rates and standing charges
  # Energy Sparks by default groups them, so the kw rates and standing
  # charges apply for the same date ranges
  def embed_standing_charges_in_rates
    @n3rgy_parameterised_tariff[:kwh_rates].map do |kwh_date_range, kwh_rate|
      standing_charges = standing_charges_for_date_range(kwh_date_range)
      standing_charges.map { |sc| merge_tariffs(sc, kwh_date_range, kwh_rate) }
    end.flatten
  end

  def merge_tariffs(standing_charge, kwh_date_range, kwh_rate)
    overlap_dates = intersect_overlapping_date_ranges(standing_charge.keys.first, kwh_date_range)
    tariff = {
      start_date:       overlap_dates.first,
      end_date:         overlap_dates.last,
      name:             'Tariff from DCC SMETS2 meter',
      standing_charge:  standing_charge.values.first
    }
    tariff.merge(convert_rates(kwh_rate))
  end

  def standing_charges_for_date_range(kwh_date_range)
    @n3rgy_parameterised_tariff[:standing_charges].map do |standing_charge_date_range, standing_charge|
      dri = intersect_dateranges(standing_charge_date_range, kwh_date_range)
      dri.nil? ? nil : { dri => { per: :day, rate: standing_charge }}
    end.compact
  end

  def convert_rates(rates)
    if rates.length == 1
      raise UnexpectedNon24HourRangeForFlatRate, "time of day range  #{rates.keys.first} doesnt cover 24 hours" unless whole_24_hours?(rates.keys.first)
      {
        rate: {
          per:    :kwh,
          rate:   rates.values.first
        },
        type: :flat_rate
      }
    else

      rates.map.with_index do |(time_of_day_range, rate), index|
        [
          "rate#{index}".to_sym,
          {
            from:   time_of_day_range.first,
            to:     time_of_day_range.last,
            per:    :kwh,
            rate:   rate
          }
        ]
      end.to_h.merge({ type: :differential })
    end
  end

  def whole_24_hours?(time_of_day_range)
    time_of_day_range.first == TimeOfDay.new( 0,  0) &&
    time_of_day_range.last  == TimeOfDay.new(23, 30)
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
