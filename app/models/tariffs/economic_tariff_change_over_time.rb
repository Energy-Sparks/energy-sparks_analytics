require_relative './meter_tariff'

class EconomicTariffChangeOverTime < MeterTariff
  class EconomicTariffsDontCoverWholeDateRange < StandardError; end
  attr_reader :tariffs

  def initialize(meter, tariffs)
    @tariffs = default_missing_dates(meter, tariffs)
    check_tariff_configuration(@tariffs)
  end

  def rate(date, type)
    tariff = find_tariff(date) # allow to blow up if nil returned unexpected to save test which would reduce performance
    tariff.rate(nil, type)
  end

  def tariff_on_date(date)
    tariff = find_tariff(date)
    tariff.tariff[:rates]
  end

  def weighted_cost(date, kwh_x48, type)
    tariff = find_tariff(date) # allow to blow up if nil returned unexpected to save test which would reduce performance
    tariff.weighted_cost(nil, kwh_x48, type)
  end

  # returns hash meter attribute representation
  def tariffs_by_date_range
    @tariffs.transform_values { |tariff| tariff.tariff[:rates] }
  end

  private

  def find_tariff(date)
    @tariffs.each do |date_range, tariff|
      return tariff if date >= date_range.first && date <= date_range.last
    end

    raise EnergySparksUnexpectedStateException, "Economic tariff not configured for #{date} should have been trapped by check_tariff_configuration method"
  end

  def default_missing_dates(meter, tariffs)
    tariffs.map do |tariff|
      tariff[:start_date] = MIN_DEFAULT_START_DATE unless tariff.key?(:start_date)
      tariff[:end_date]   = MAX_DEFAULT_END_DATE   unless tariff.key?(:end_date)
      [tariff[:start_date]..tariff[:end_date], EconomicTariff.new(meter, tariff)]
    end.sort_by { |dr_tariff_pair| dr_tariff_pair[0].first }.to_h
  end

  def check_tariff_configuration(tariffs)
    date_ranges = tariffs.keys

    check_start_end_dates(date_ranges)
    date_ranges_contiguous(date_ranges)
  end

  def check_start_end_dates(date_ranges)
    date_ranges.each do |date_range|
      if date_range.first > date_range.last
        raise EconomicTariffsDontCoverWholeDateRange, "Economic tariff start_date (#{date_range.first} > end_date (#{date_range.last})"
      end
    end
  end

  def date_ranges_contiguous(date_ranges)
    error_message = "economic tariffs must have contiguous between #{MIN_DEFAULT_START_DATE} and #{MAX_DEFAULT_END_DATE}"
    sorted_date_ranges = date_ranges.sort_by { |dr| dr.first }

    start_date = MIN_DEFAULT_START_DATE

    sorted_date_ranges.each do |date_range|
      if date_range.first != start_date
        raise EconomicTariffsDontCoverWholeDateRange, "Incorrectly set economic tariff start date: #{start_date} #{error_message}"
      end
      start_date = date_range.last + 1
    end

    if start_date - 1 != MAX_DEFAULT_END_DATE
      raise EconomicTariffsDontCoverWholeDateRange, "Incorrectly set economic tariff end date: #{start_date - 1} #{error_message}"
    end
  end
end
