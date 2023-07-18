class MeterTariff
  attr_reader :tariff, :fuel_type
  FLAT_RATE = 'flat_rate'.freeze
  DAYTIME_RATE = 'daytime_rate'.freeze
  NIGHTTIME_RATE = 'nighttime_rate'.freeze
  MIN_DEFAULT_START_DATE = Date.new(2008, 1, 1)
  MAX_DEFAULT_END_DATE   = Date.new(2050, 1, 1)

  def initialize(meter, tariff)
    @mpxn       = meter.mpxn
    @amr_data   = meter.amr_data
    @fuel_type  = meter.fuel_type
    @tariff     = tariff
  end

  def default?
    @tariff[:default] == true
  end

  def dcc?
    @tariff[:source] == :dcc
  end

  def backdate_tariff(start_date)
    logger.info "Backdating (DCC) tariff for #{@mpxn} start date to #{start_date}"
    @tariff[:start_date] = start_date
  end

  def in_date_range?(date)
    date >= @tariff[:start_date] && date <= @tariff[:end_date]
  end

  def times(type)
    @tariff[:rates][type][:from]..@tariff[:rates][type][:to]
  end

  def rate(_date, type)
    @tariff[:rates][type][:rate]
  end

  def tariff_on_date(_date)
    @tariff[:rates]
  end

  def self.rates_text(tariffs_by_date, is_differential)
    rt = {}

    tariffs_by_date.each do |date_range, rates|
      rt[date_range_text(date_range)] = rate_text(rates, is_differential)
    end

    rt
  end

  def self.date_range_text(date_range)
    start_date_text = date_text(date_range.first)
    end_date_text   = date_text(date_range.last)

    return nil if start_date_text.nil? && end_date_text.nil?

    return "to #{end_date_text}" if start_date_text.nil?

    return "from #{start_date_text}" if end_date_text.nil?

    "#{start_date_text} to #{end_date_text}"
  end

  def self.rate_text(rates, is_differential)
    flat_rate_text = FormatEnergyUnit.format(:£_per_kwh, rates[:rate][:rate], :text)
    return flat_rate_text unless rates.key?(:daytime_rate) && is_differential

    dr = FormatEnergyUnit.format(:£_per_kwh, rates[:daytime_rate][:rate], :text)
    nr = FormatEnergyUnit.format(:£_per_kwh, rates[:nighttime_rate][:rate], :text)
    "rate: #{flat_rate_text}, differential: (day #{dr}, night #{nr})"
  end

  def self.date_ranged_rate_text(type, rate)
    rate_type = type == :daytime_rate ? 'day time' : 'night time'
  end

  def self.infinite_date?(date)
    [MIN_DEFAULT_START_DATE, MAX_DEFAULT_END_DATE].include?(date)
  end

  def self.date_text(date)
    return nil if MeterTariff.infinite_date?(date)
    date.strftime('%b %Y')
  end

  def weighted_cost(_date, kwh_x48, type)
    weights = DateTimeHelper.weighted_x48_vector_single_range(times(type), rate(_date, type))
    # NB old style tariffs have exclusive times
    AMRData.fast_multiply_x48_x_x48(weights, kwh_x48)
  end

  def self.format_time_range(rate)
    "#{rate[:from]} to #{rate[:to]}".freeze
  end

  def tariffs_by_date_range
    {
      MIN_DEFAULT_START_DATE..MAX_DEFAULT_END_DATE => @tariff[:rates]
    }
  end

  def tariffs_within_date_range(start_date, end_date)
    tariffs_by_date_range.select do |dr, rates|
      start_date.between?(dr.first, dr.last) || end_date.between?(dr.first, dr.last)
    end
  end

  def tariffs_differ_within_date_range?(start_date, end_date)
    trs = tariffs_within_date_range(start_date, end_date)
    trs.values.uniq.length > 1
  end

  def meter_tariffs_changes_between_periods?(period1, period2)
    trs1 = tariffs_within_date_range(period1.first, period1.last)
    trs2 = tariffs_within_date_range(period2.first, period2.last)
    # works simplistically where the tariffs differ
    # but potentially problematic if tariff transition is
    # identical within both periods but the transition occurs
    # within differing numbers of days into the transition
    # - shouldn't happen often as would require for example
    # - tariff to increase, then decrease, then increase to same
    #   value as previous high, then decrease to same value as
    #   previous decrease
    # two periods
    trs1.values != trs2.values
  end
end

class EconomicTariff < MeterTariff
end
