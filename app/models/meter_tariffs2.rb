# Economic Tariffs: each meter has a system wide economic tariff
# - which can be used for both differential and non-differential cost calculations
# - to work out whether its differential or not the code below looks up the meters accounting tariff
class MeterTariffManager
  class MissingAccountingTariff < StandardError; end
  def initialize(meter)
    @meter = meter
    pre_process_tariff_attributes(meter)
  end

  def economic_cost(date, kwh_x48)
    if differential_tariff_on_date?(date)
      {
        nighttime_rate: @economic_tariff.weighted_cost(kwh_x48, :nighttime_rate),
        daytime_rate:   @economic_tariff.weighted_cost(kwh_x48, :daytime_rate)
      }
    else
      {
        flat_rate: AMRData.fast_multiply_x48_x_scalar(kwh_x48, @economic_tariff.rate(:rate))
      }
    end
  end

  def any_differential_tariff?(start_date, end_date)
    # slow, TODO(PH, 30Mar2021) speed up by scanning tariff date ranges
    (start_date..end_date).any? { |date| differential_tariff_on_date?(date) }
  end

  def differential_tariff_on_date?(date)
    accounting_tariff = accounting_tariff_for_date(date)
    !accounting_tariff.nil? && accounting_tariff.differential?(date)
  end

  def accounting_tariff_for_date(date)
    return nil if @accounting_tariffs.nil?
    tariffs = @accounting_tariffs.select { |accounting_tariff| accounting_tariff.in_date_range?(date) }
    non_default_tariffs = tariffs.select { |t| !t.default? }
    return non_default_tariffs[0] if non_default_tariffs.length == 1
    default_tariffs = tariffs.select { |t| t.default? }
    return default_tariffs[0] if default_tariffs.length == 1
    nil
  end

  def accounting_tariff_£(date, kwh_halfhour_x48)
    tariff = accounting_tariff_for_date(date)

    raise MissingAccountingTariff, "Missing tariff data for #{meter.mpan_mprn} on #{date}" if tariff.nil?

    costs_x48 = tariff.costs_x48_x2(date, kwh_x48)

    daytime_cost_x48, nighttime_cost_x48 = day_night_costs_x48(tariff_config, kwh_halfhour_x48, differential_tariff?(tariff_config))

    standing_charge = standing_charges(date, tariff_config, kwh_halfhour_x48.sum)

    [costs_x48[:daytime_rate], costs_x48[:nighttime_rate], standing_charge]
  end

  private

  def pre_process_tariff_attributes(meter)
    @economic_tariff = EconomicTariff.new(meter, meter.attributes(:economic_tariff))
    @accounting_tariffs = preprocess_accounting_tariffs(meter, meter.attributes(:accounting_tariffs))

    puts "Got 1 eco tariff and #{@accounting_tariffs.nil? ? 0 : @accounting_tariffs.length} accounting tariffs"
  end

  def preprocess_accounting_tariffs(meter, accounting_tariffs)
    return nil if accounting_tariffs.nil?
    accounting_tariffs.map do |accounting_tariff|
      AccountingTariff.new(meter, accounting_tariff)
    end
  end
end

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
  class UnexpectedRateType < StandardError; end
  def differential?(_date)
    tariff[:rates].key?(:nighttime_rate)
  end

  def costs_x48_x2(date, kwh_x48)
    if differential?(date)
      {
        nighttime_rate:   weighted_cost(kwh_x48, :nighttime_rate),
        daytime_rate:     weighted_cost(kwh_x48, :daytime_rate),
        standing_charges: standing_charges(date, kwh_x48.sum)
      }
    else
      {
        nighttime_rate:   nil, # AMRData.one_day_zero_kwh_x48,
        daytime_rate:     AMRData.fast_multiply_x48_x_scalar(kwh_x48, tariff[:rates][:rate][:rate]),
        standing_charges: standing_charges(date, kwh_x48.sum)
      }
    end
  end

  def standing_charges(date, days_kwh)
    standing_charge = {}
    tariff[:rates].each do |standing_charge_type, rate|
      next if [:rate, :daytime_rate, :nighttime_rate].include?(standing_charge_type)
      standing_charge[standing_charge_type] = daily_rate(date, rate[:per], rate[:rate], days_kwh)
    end
    standing_charge
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

    private_class_method def self.generic_tariff?(tariff_config)
      tariff_config[:rates].keys.any?{ |type| type.to_s.match(/rate[0-9]/) }
    end
  end
end
