# Economic Tariffs: each meter has a system wide economic tariff
# - which can be used for both differential and non-differential cost calculations
# - to work out whether its differential or not the code below looks up the meters accounting tariff
class MeterTariffManager
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

  def any_differential_tariff(start_date, end_date)
    # slow, TODO(PH, 30Mar2021) speed up by scanning tariff date ranges
    (start_date..end_date).any? { |date| differential_tariff_on_date?(date) }
  end

  def differential_tariff_on_date?(date)
    accounting_tariff = accounting_tariff_for_date(date)
    !accounting_tariff.nil? && accounting_tariff.tariff[:rates].key?(:nighttime_rate)
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

  def accounting_tariff_for_date(date)
    return nil if @accounting_tariffs.nil?
    tariffs = @accounting_tariffs.select { |accounting_tariff| accounting_tariff.in_date_range?(date) }
    non_default_tariffs = tariffs.select { |t| !t.default? }
    return non_default_tariffs[0] if non_default_tariffs.length == 1
    default_tariffs = tariffs.select { |t| t.default? }
    return default_tariffs[0] if default_tariffs.length == 1
    nil
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

  def times(type = :nighttime_rate)
    @tariff[:rates][type][:from]..@tariff[:rates][type][:to]
  end

  def rate(type = :nighttime_rate)
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
end


