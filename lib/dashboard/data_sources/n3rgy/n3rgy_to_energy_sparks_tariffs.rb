class N3rgyToEnergySparksTariffs
  def initialize(n3rgy_parameterised_tariff)
    @n3rgy_parameterised_tariff = n3rgy_parameterised_tariff
  end

  def convert
    return nil if @n3rgy_parameterised_tariff.nil?
    puts "Energy Sparks tariffs: In"
    ap @n3rgy_parameterised_tariff
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
    {
      start_date:       overlap_dates.first,
      end_date:         overlap_dates.last,
      name:             'Tariff from DCC SMETS2 meter',
      rates:            kwh_rate,
      standing_charge:  standing_charge.values.first
    }
  end

  def standing_charges_for_date_range(kwh_date_range)
    @n3rgy_parameterised_tariff[:standing_charges].map do |standing_charge_date_range, standing_charge|
      dri = intersect_dateranges(standing_charge_date_range, kwh_date_range)
      dri.nil? ? nil : { dri => standing_charge }
    end.compact
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
