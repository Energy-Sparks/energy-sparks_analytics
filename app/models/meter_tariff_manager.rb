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

  def economic_cost_backwards_compatible(date, kwh_x48)
    costs = economic_cost(date, kwh_x48)
    if costs.key?(:flat_rate)
      [costs[:flat_rate], AMRData.one_day_zero_kwh_x48, {}]
    else
      [costs[:daytime_rate], costs[:nighttime_rate], {}]
    end
  end

  def accounting_tariff_x48_backwards_compatible(date, kwh_x48)
    costs = accounting_tariff_£(date, kwh_x48)

    [costs[:daytime_rate], costs[:nighttime_rate], costs[:standing_charges]]
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

  private

  def accounting_tariff_£(date, kwh_x48)
    tariff = accounting_tariff_for_date(date)

    raise MissingAccountingTariff, "Missing tariff data for #{@meter.mpxn} on #{date}" if tariff.nil?

    costs_x48 = tariff.costs_x48_x2(date, kwh_x48)

    costs_x48.merge({ standing_charges: tariff.standing_charges(date, kwh_x48.sum) })
  end

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