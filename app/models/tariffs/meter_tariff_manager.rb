# MeterTariffManager: manages all the tariffs associated with a given meter
#                     these tariffs are either generated from the DCC or manually edited by the user
#                     the managers main job is to select the right type of tariff for a given date
#                     there is potentially a complex hierarchy of these tariffs to select from
#
# Economic Tariffs: each meter has a system wide economic tariff
# - which can be used for both differential and non-differential cost calculations
# - to work out whether its differential or not the code below looks up the meters accounting tariff
# Accounting Tariffs
# - there are potentially multiple of these for a given day, the manager decided which:
# - accounting_tariff
# - override tariff     - highest precedence typically used to override bad data from dcc, only applies to generic
# - merge tariff        - used to add tariff information e.g. DUOS rates not available on the DCC
#
# Summary: the manager selects the most relevant tariff for a given date
#
class MeterTariffManager
  attr_reader :accounting_tariffs

  class MissingAccountingTariff                                   < StandardError; end
  class OverlappingAccountingTariffs                              < StandardError; end
  class WeekdayTypeNotSetForWeekdayTariff                         < StandardError; end
  class OverlappingAccountingTariffsForWeekdayTariff              < StandardError; end
  class NotAllWeekdayWeekendTariffsOnDateAreWeekdayWeekendTariffs < StandardError; end
  class TooManyWeekdayWeekendTariffsOnDate                        < StandardError; end
  class MissingWeekdayWeekendTariffsOnDate                        < StandardError; end

  def initialize(meter)
    @mpxn = meter.mpxn
    pre_process_tariff_attributes(meter)
  end

  def economic_cost(date, kwh_x48)
    t = if differential_tariff_on_date?(date)
          {
            rates_x48: {
              MeterTariff::NIGHTTIME_RATE => @economic_tariff.weighted_cost(kwh_x48, :nighttime_rate),
              MeterTariff::DAYTIME_RATE   => @economic_tariff.weighted_cost(kwh_x48, :daytime_rate)
            },
            differential: true
          }
        else
          {
            rates_x48: {
              MeterTariff::FLAT_RATE => AMRData.fast_multiply_x48_x_scalar(kwh_x48, @economic_tariff.rate(:rate))
            },
            differential: false
          }
        end

    t.merge( { standing_charges: {}, system_wide: true, default: true } )
  end

  def accounting_cost(date, kwh_x48)
    tariff = accounting_tariff_for_date(date)
    
    return nil if tariff.nil?

    tariff.costs(date, kwh_x48)
  end

  # used by meter consolidation tariff; attempt real tariff, otherwise default indicative
  def meter_standing_charge_£_per_day(date)
    tariff = calculate_accounting_tariff_for_date(date, true)
    return @indicative_standing_charge.daily_standing_charge_£_per_day if tariff.nil?
    c = tariff.costs(date, AMRData.one_day_zero_kwh_x48)
    c[:standing_charges].values.sum
  end

  def any_differential_tariff?(start_date, end_date)
    # slow, TODO(PH, 30Mar2021) speed up by scanning tariff date ranges
    # this is now more complex as there are now potentially multiple tariffs on
    # a date with different rules
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

  def most_recent_contiguous_real_accounting_tariffs
    return nil if @accounting_tariffs.nil? || @accounting_tariffs.empty?

    reverse_sorted_tariffs = @accounting_tariffs.sort { |t1, t2| t2.tariff[:end_date] <=> t1.tariff[:end_date] }

    grouped_tariffs = reverse_sorted_tariffs.slice_when { |prev, curr| prev.tariff[:end_date] < prev.tariff[:start_date] - 1 }.to_a

    most_recent_contiguous_tariff_group = grouped_tariffs[0]

    start_date = most_recent_contiguous_tariff_group.last.tariff[:start_date]
    end_date   = most_recent_contiguous_tariff_group.first.tariff[:end_date]

    {
      start_date: start_date,
      end_date:   end_date,
      days:       (end_date - start_date + 1).to_i,
      tariffs:    most_recent_contiguous_tariff_group.reverse
    }
  end

  def accounting_tariff_for_date(date)
    @accounting_tariff_cache       ||= {}
    @accounting_tariff_cache[date] ||= calculate_accounting_tariff_for_date(date)
  end

  private

  def calculate_accounting_tariff_for_date(date, ignore_defaults = false)
    override = override_tariff(date)
    return override unless override.nil?

    return nil if @accounting_tariffs.nil?

    accounting_tariff = find_tariff(date)

    accounting_tariff = find_default_tariff(date) if !ignore_defaults && accounting_tariff.nil?

    # this should only happen for when ignore_defaults = true; meter consolidation alert
    return nil if accounting_tariff.nil?

    merge = merge_tariff(date)
    return accounting_tariff.deep_merge(merge) unless merge.nil?

    accounting_tariff
  end

  def find_tariff(date)
    tariffs = @accounting_tariffs.select { |accounting_tariff| accounting_tariff.in_date_range?(date) }

    choosen_weekend_weekday_tariff = weekend_weekday_tariff(tariffs, date)

    if choosen_weekend_weekday_tariff.nil?
      tariffs.empty? ? nil : tariffs[0]
    else
      choosen_weekend_weekday_tariff
    end
  end

  # deal with legacy issue of multiple default accounting tariffs
  # pick up non-system wide first
  def find_default_tariff(date)
    tariffs = @default_accounting_tariffs.select { |accounting_tariff| accounting_tariff.in_date_range?(date) }

    return nil if tariffs.empty?
    return tariffs[0] if tariffs.length == 1

    group_specific_tariffs = tariffs.select { |t| !t.system_wide? }
    return group_specific_tariffs[0] unless group_specific_tariffs.empty?

    tariffs[0]
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
    return nil if @differential_tariff_override.empty?

    @differential_tariff_override.any? { |dr, tf| date >= dr.first && date <= dr.last && tf }
  end

  def pre_process_tariff_attributes(meter)
    @economic_tariff = EconomicTariff.new(meter, meter.attributes(:economic_tariff))
    @accounting_tariffs = preprocess_accounting_tariffs(meter, meter.attributes(:accounting_tariffs), false) || []
    @default_accounting_tariffs = preprocess_accounting_tariffs(meter, meter.attributes(:accounting_tariffs), true) || []
    @accounting_tariffs += preprocess_generic_accounting_tariffs(meter, meter.attributes(:accounting_tariff_generic)) || []
    @override_tariffs = preprocess_generic_accounting_tariffs(meter, meter.attributes(:accounting_tariff_generic_override)) || []
    @merge_tariffs = preprocess_generic_accounting_tariffs(meter, meter.attributes(:accounting_tariff_generic_merge)) || []
    @differential_tariff_override = process_economic_tariff_override(meter.attributes(:economic_tariff_differential_accounting_tariff))
    @indicative_standing_charge = MeterIndicativeStandingCharge.new(meter, meter.attributes(:indicative_standing_charge))
    check_tariffs
  end

  def process_economic_tariff_override(differential_overrides)
    return {} if differential_overrides.nil?

    differential_overrides.map do |override|
      end_date = override[:end_date] || Date.new(2050, 1, 1)
      [
        override[:start_date]..end_date,
        override[:differential]
      ]
    end.to_h
  end

  def preprocess_accounting_tariffs(meter, accounting_tariffs, default)
    return [] if accounting_tariffs.nil?

    # TODO (PH, 25Apr2021) remove once all default accounting tariffs are removed from the database
    tariffs = accounting_tariffs.select do |t|
      if default
        t[:default] == true
      else
        t[:default] != true # nil || false
      end
    end

    tariffs.map do |accounting_tariff|
      AccountingTariff.new(meter, accounting_tariff)
    end
  end

  def preprocess_generic_accounting_tariffs(meter, accounting_tariffs)
    return [] if accounting_tariffs.nil?

    accounting_tariffs.map do |accounting_tariff|
      GenericAccountingTariff.new(meter, accounting_tariff)
    end
  end

  def check_tariffs
    @accounting_tariffs.combination(2) do |t1, t2|
      r = t1.tariff[:start_date]..t1.tariff[:end_date]
      if r.cover?(t2.tariff[:start_date]) || r.cover?(t2.tariff[:end_date])
        if t1.tariff[:sub_type] != :weekday_weekend || t2.tariff[:sub_type] != :weekday_weekend
          raise_and_log_error(OverlappingAccountingTariffs, "Overlapping (date) accounting tariffs #{@mpxn}")
        elsif weekday_type?(t1) == weekday_type?(t2)
          raise_and_log_error(OverlappingAccountingTariffsForWeekdayTariff, "Overlapping weekday accounting tariffs #{@mpxn}")
        end
      end
    end
  end

  def weekday_type?(tariff)
    if tariff.tariff[:weekday]
      :weekday
    elsif tariff.tariff[:weekend]
      :weekend
    else
      raise_and_log_error(WeekdayTypeNotSetForWeekdayTariff, "Missing weekday type for tariff #{@mpxn}")
    end
  end

  # weekday/weekend tariffs are typically represented by 2 tariffs within a given supply contract
  # i.e. have same or very similar start and end dates, but are differentiated by having
  # [:weekday] or [:weekend] flags set, ultimately only 1 of the 2 tariffs is used depending on the date
  # generally you would expect zero or 1 weekday/weekend tariff on a given date 
  def weekend_weekday_tariff(tariffs, date)
    weekday_tariffs = tariffs.select { |tariff| tariff.tariff.key?(:weekday) }
    weekend_tariffs = tariffs.select { |tariff| tariff.tariff.key?(:weekend) }

    return nil if weekday_tariffs.empty? && weekend_tariffs.empty?

    check_weekday_weekend_tariffs(tariffs, weekday_tariffs, weekend_tariffs, date)

    weekend?(date) ? weekend_tariffs[0] : weekday_tariffs[0]
  end

  # defensive programming on basis either user or dcc might setup tariffs incorrectly
  def check_weekday_weekend_tariffs(tariffs, weekday_tariffs, weekend_tariffs, date)
    if tariffs.length != weekday_tariffs.length + weekend_tariffs.length 
      raise_and_log_error(NotAllWeekdayWeekendTariffsOnDateAreWeekdayWeekendTariffs, "Not all tariffs on #{date} for mpxn #{@mpxn} are  weekday weekend tariffs")
    end

    if weekday_tariffs.length > 1 || weekend_tariffs.length > 1
      raise_and_log_error(TooManyWeekdayWeekendTariffsOnDate, "Too many weekend/weekday tariffs on #{date} for mpxn #{@mpxn}")
    end

    if weekend?(date)
      if weekend_tariffs.empty? || weekend_tariffs[0].tariff[:weekend] != true
        raise_and_log_error(MissingWeekdayWeekendTariffsOnDate, "Missing or set false weekend tariff on #{date} for mpxn #{@mpxn}")
      end
    elsif weekday_tariffs.empty? || weekday_tariffs[0].tariff[:weekday] != true
      raise_and_log_error(MissingWeekdayWeekendTariffsOnDate, "Missing weekday or set false tariff on #{date} for mpxn #{@mpxn}")
    end
  end

  def weekend?(date)
    date.saturday? || date.sunday?
  end

  def raise_and_log_error(exception, message)
    logger.info message
    logger.info data
    raise exception, message
  end
end
