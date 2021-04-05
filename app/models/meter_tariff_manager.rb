# Economic Tariffs: each meter has a system wide economic tariff
# - which can be used for both differential and non-differential cost calculations
# - to work out whether its differential or not the code below looks up the meters accounting tariff
# Accounting Tariffs
# - there are potentially multiple of these for a given day, the manager decided which:
# - a 'default' tariff  - i.e. a system wide tariff has lowest precedence and shouldn't be used
#                       - as school groups typically don't have default tariffs, and the default
#                       - shouldn't be used to determine whether the economic tariff is differential or not
# - override tariff     - highest precedence typically used to override bad data from dcc, only applies to generic
# - merge tariff        - used to add tariff information e.g. DUOS rates not available on the DCC
class MeterTariffManager
  attr_reader :accounting_tariffs
  class MissingAccountingTariff < StandardError; end
  class OverlappingAccountingTariffs < StandardError; end
  def initialize(meter)
    @meter = meter
    pre_process_tariff_attributes(meter)
  end

  def economic_cost(date, kwh_x48)
    if differential_tariff_on_date?(date)
      {
        rates_x48: {
          nighttime_rate: @economic_tariff.weighted_cost(kwh_x48, :nighttime_rate),
          daytime_rate:   @economic_tariff.weighted_cost(kwh_x48, :daytime_rate)
        },
        standing_charges: {},
        differential: true
      }
    else
      {
        rates_x48: {
          flat_rate: AMRData.fast_multiply_x48_x_scalar(kwh_x48, @economic_tariff.rate(:rate))
        },
        standing_charges: {},
        differential: false  
      }
    end
  end
  
  def accounting_cost(date, kwh_x48)
    tariff = accounting_tariff_for_date(date)

    raise MissingAccountingTariff, "Missing tariff data for #{@meter.mpxn} on #{date}" if tariff.nil?

    tariff.costs(date, kwh_x48)
  end

  def any_differential_tariff?(start_date, end_date)
    # slow, TODO(PH, 30Mar2021) speed up by scanning tariff date ranges
    (start_date..end_date).any? { |date| differential_tariff_on_date?(date) }
  end

  def differential_tariff_on_date?(date)
    override = differential_override(date)
    if override.nil?
      accounting_tariff = accounting_tariff_for_date(date)
      !accounting_tariff.nil? && accounting_tariff.differential?(date)
    else
      override
    end
  end

  def accounting_tariff_for_date(date)
    override = override_tariff(date)
    return override unless override.nil?

    return nil if @accounting_tariffs.nil?
    accounting_tariff = default_tariff(date, false) || default_tariff(date, true)

    merge = merge_tariff(date)
    return accounting_tariff.deep_merge(merge) unless merge.nil?

    accounting_tariff
  end

  private

  def default_tariff(date, default)
    tariffs = select_default_tariffs(date, default)
    tariffs.empty? ? nil : tariffs[0]
  end

  def select_default_tariffs(date, default)
    tariffs = @accounting_tariffs.select { |accounting_tariff| accounting_tariff.in_date_range?(date) }
    tariffs.select { |t| t.default? == default }
  end

  def override_tariff(date)
    override = @override_tariffs.select { |accounting_tariff| accounting_tariff.in_date_range?(date) }
    override.empty? ? nil : override[0]
  end

  def merge_tariff(date)
    override = @merge_tariffs.select { |accounting_tariff| accounting_tariff.in_date_range?(date) }
    override.empty? ? nil : override[0]
  end

  def differential_override(date)
    return nil if @differential_tariff_override.nil?
    @differential_tariff_override.any?{ |dr, tf| date >= dr.first && date <= dr.last && tf }
  end

  def pre_process_tariff_attributes(meter)
    @economic_tariff = EconomicTariff.new(meter, meter.attributes(:economic_tariff))
    @accounting_tariffs = preprocess_accounting_tariffs(meter, meter.attributes(:accounting_tariffs)) || []
    @accounting_tariffs += preprocess_generic_accounting_tariffs(meter, meter.attributes(:accounting_tariff_generic)) || []
    @override_tariffs = preprocess_generic_accounting_tariffs(meter, meter.attributes(:accounting_tariff_generic_override)) || []
    @merge_tariffs = preprocess_generic_accounting_tariffs(meter, meter.attributes(:accounting_tariff_generic_merge)) || []
    @differential_tariff_override = process_economic_tariff_override(meter.attributes(:economic_tariff_differential_accounting_tariff))
    check_tariffs
  end

  def process_economic_tariff_override(diffential_overrides)
    return nil if diffential_overrides.nil?
    diffential_overrides.map do |override|
      end_date = override[:end_date] || Date.new(2050, 1, 1)
      [
        override[:start_date]..end_date,
        override[:differential]
      ]
    end.to_h
  end

  def preprocess_accounting_tariffs(meter, accounting_tariffs)
    return nil if accounting_tariffs.nil?
    accounting_tariffs.map do |accounting_tariff|
      AccountingTariff.new(meter, accounting_tariff)
    end
  end

  def preprocess_generic_accounting_tariffs(meter, accounting_tariffs)
    return nil if accounting_tariffs.nil?
    accounting_tariffs.map do |accounting_tariff|
      GenericAccountingTariff.new(meter, accounting_tariff)
    end
  end

  def check_tariffs
    check_overlapping_accounting_tariffs_default_type(@accounting_tariffs, true)
    check_overlapping_accounting_tariffs_default_type(@accounting_tariffs, false)
  end

  def check_differential_tariffs_times(tariff)
  end

  def check_overlapping_accounting_tariffs_default_type(tariff_type, default)
    tariffs = tariff_type.select { |t| t.default? == default }
    tariffs.combination(2) do |t1, t2|
      r = t1.tariff[:start_date]..t1.tariff[:end_date]
      if r.cover?(t2.tariff[:start_date]) || r.cover?(t2.tariff[:end_date])
        raise OverlappingAccountingTariffs, "Overlapping (date) accounting tariffs default = #{default} #{@meter.mpxn}"
      end
    end
  end
end