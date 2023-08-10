# Manages all the tariffs associated with a given meter
# these tariffs are either generated from the DCC or manually edited by the user
# the managers main job is to select the right type of tariff for a given date
# there is potentially a complex hierarchy of these tariffs to select from
#
# Economic Tariffs: each meter has a system wide economic tariff
# - which can be used for both differential and non-differential cost calculations
# - to work out whether its differential or not the code below looks up the meters accounting tariff
# Accounting Tariffs
# - there are potentially multiple of these for a given day, the manager decided which will be used:
# - accounting_tariff
#
# Summary: the manager selects the most relevant tariff for a given date
class MeterTariffManager
  include Logging
  MAX_DAYS_BACKDATE_TARIFF = 30
  attr_reader :accounting_tariffs, :economic_tariff, :meter

  class MissingAccountingTariff                                   < StandardError; end
  class OverlappingAccountingTariffs                              < StandardError; end
  class WeekdayTypeNotSetForWeekdayTariff                         < StandardError; end
  class OverlappingAccountingTariffsForWeekdayTariff              < StandardError; end
  class NotAllWeekdayWeekendTariffsOnDateAreWeekdayWeekendTariffs < StandardError; end
  class TooManyWeekdayWeekendTariffsOnDate                        < StandardError; end
  class MissingWeekdayWeekendTariffsOnDate                        < StandardError; end
  class EconomicCostCalculationError                              < StandardError; end

  def initialize(meter)
    @mpxn = meter.mpxn
    @meter = meter # messy when printing object
    pre_process_tariff_attributes(meter)
    backdate_dcc_tariffs(meter)
  end

  #Calculate the economic cost for a given date and one days worth
  # of half-hourly consumption
  #
  # Returns a hash which can be used to a OneDaysCostData object
  # TODO: could just create that directly?
  def economic_cost(date, kwh_x48)
    differential_tariff = differential_tariff_on_date?(date)
    t = if differential_tariff
          {
            rates_x48: {
              MeterTariff::NIGHTTIME_RATE => @economic_tariff.weighted_cost(date, kwh_x48, :nighttime_rate),
              MeterTariff::DAYTIME_RATE   => @economic_tariff.weighted_cost(date, kwh_x48, :daytime_rate)
            },
            differential: true
          }
        else
          {
            rates_x48: {
              MeterTariff::FLAT_RATE => AMRData.fast_multiply_x48_x_scalar(kwh_x48, @economic_tariff.rate(date, :rate))
            },
            differential: false
          }
        end

    t.merge!( { standing_charges: {}, system_wide: true, default: true, tariff: @economic_tariff } )
    OneDaysCostData.new(t)
  rescue => e
    raise_and_log_error(EconomicCostCalculationError, "Unable to calculate economic cost for mpxn #{@mpxn} on #{date}. Differential tariff: #{differential_tariff}")
  end

  #Calculate the accounting cost for a given date and one days worth
  # of half-hourly consumption
  #
  # Returns a hash which can be used to create a OneDaysCostData object
  # TODO: could just create that directly?
  def accounting_cost(date, kwh_x48)
    tariff = accounting_tariff_for_date(date)

    return nil if tariff.nil?

    tariff.costs(date, kwh_x48)
  end

  #Determine whether there are any differential tariffs within the specified date range
  def any_differential_tariff?(start_date, end_date)
    # slow, TODO(PH, 30Mar2021) speed up by scanning tariff date ranges
    # this is now more complex as there are now potentially multiple tariffs on
    # a date with different rules
    (start_date..end_date).any? { |date| differential_tariff_on_date?(date) }
  end

  # Find the accounting tariff for the given date
  # Caches the calculation of the accounting tariff
  def accounting_tariff_for_date(date)
    @accounting_tariff_cache       ||= {}
    @accounting_tariff_cache[date] ||= calculate_accounting_tariff_for_date(date)
  end

  #Does this meter have time-varying economic tariffs?
  def economic_tariffs_change_over_time?
    # probably only works on real meters, not aggregate meters
    check_economic_tariff_type
    @economic_tariff.class == EconomicTariffChangeOverTime
  end

  # Find the most recent date that the tariffs were last changed
  def last_tariff_change_date(start_date = @meter.amr_data.start_date, end_date = @meter.amr_data.end_date)
    change_dates = tariff_change_dates_in_period(start_date, end_date)
    return nil if change_dates.empty?

    change_dates.last
  end

  # Find all the dates when the tariff changes within the period
  def tariff_change_dates_in_period(start_date  = @meter.amr_data.start_date, end_date = @meter.amr_data.end_date)
    start_date, end_date = default_nil_date_ranges(start_date, end_date)

    tariff_changes = tariffs_within_date_range(start_date, end_date)
    date_ranges = tariff_changes.values.map { |tar| tar.keys }.flatten.uniq
    dates = date_ranges.map { |dr| [dr.first, dr.last] }.flatten.uniq.sort

    change_dates = dates.reject { |d| MeterTariff.infinite_date?(d) }

    change_dates_with_in_range = change_dates.reject { |d| d < start_date || d > end_date }
  end

  # Have the economic tariffs changed within this date range?
  #
  # e.g. aggregate_meter.meter_tariffs.meter_tariffs_differ_within_date_range?(Date.new(2022,8,22), Date.new(2022,10,22))
  def meter_tariffs_differ_within_date_range?(start_date, end_date)
    constituent_meters.any? do |meter|
      meter.meter_tariffs.economic_tariff.tariffs_differ_within_date_range?(start_date, end_date)
    end
  end

  # Have the economic tariffs changed between these date ranges?
  def meter_tariffs_changes_between_periods?(period1, period2)
    constituent_meters.any? do |meter|
      meter.meter_tariffs.economic_tariff.meter_tariffs_changes_between_periods?(period1, period2)
    end
  end

  private

  #Determine whether there's a differential tariff for a specific date
  def differential_tariff_on_date?(date)
    accounting_tariff = accounting_tariff_for_date(date)
    !accounting_tariff.nil? && accounting_tariff.differential?(date)
  end

  # Find all the tariffs for the underlying meters for a specific date range
  #
  # meter => { date_ranges => tariffs }
  def tariffs_within_date_range(start_date, end_date)
    start_date, end_date = default_nil_date_ranges(start_date, end_date)

    constituent_meters.map do |constituent_meter|
      [
        constituent_meter,
        constituent_meter.meter_tariffs.economic_tariff.tariffs_within_date_range(start_date, end_date)
      ]
    end.to_h
  end

  def default_nil_date_ranges(start_date, end_date)
    start_date = MeterTariff::MIN_DEFAULT_START_DATE if start_date.nil?
    end_date   = MeterTariff::MAX_DEFAULT_END_DATE   if end_date.nil?
    [start_date, end_date]
  end

  #Determine the accounting tariff for a given day
  #
  #This is the method that does main work of finding the right accounting tariff
  #to use for a given date.
  #
  #By default it will:
  # - find the real (non-default) accounting tariff for the date, preferring weekend/weekday tariffs if available
  #   this includes checking smart meter tariffs
  # - find the default accounting tariff for that day
  def calculate_accounting_tariff_for_date(date, ignore_defaults = false)
    return nil if @accounting_tariffs.nil?
    accounting_tariff = find_tariff(date)
    accounting_tariff = find_default_tariff(date) if !ignore_defaults && accounting_tariff.nil?
    #may be nil if ignore_defaults = true
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

  #Create the collections of models that represent the different categories of tariff for this
  #meter
  def pre_process_tariff_attributes(meter)
    #Creates either an EconomicTariff or an EconomicTariffChangeOverTime instance from the
    #economic tariff. The latter will end up using a number of meter attributes.
    @economic_tariff = pre_process_economic_tariffs(meter)
    #Create an AccountingTariff for each accounting tariff attribute, separating out those that are defaults
    @accounting_tariffs = preprocess_accounting_tariffs(meter, meter.attributes(:accounting_tariffs), false) || []
    @default_accounting_tariffs = preprocess_accounting_tariffs(meter, meter.attributes(:accounting_tariffs), true) || []

    #Create GenericAccountingTariff for tariffs from the DCC
    @accounting_tariffs += preprocess_generic_accounting_tariffs(meter, meter.attributes(:accounting_tariff_generic)) || []

    #Validate the accounting tariffs to raise an exception if there are overlaps
    check_tariffs
  end

  def pre_process_economic_tariffs(meter)
    if meter.attributes(:economic_tariff_change_over_time).nil? || meter.attributes(:economic_tariff_change_over_time).empty?
      # pre October 2022 version of economic tariffs - same value for all time
      EconomicTariff.new(meter, meter.attributes(:economic_tariff))
    else
      # post October 2022 version of economic tariffs - tariffs potentiall change with start, end_date over time
      EconomicTariffChangeOverTime.new(meter, meter.attributes(:economic_tariff_change_over_time))
    end
  end

  #TODO: this seems unnecessary, the economic tariff object can only be one of the two
  #types being checked.
  def check_economic_tariff_type
    economic_tariff_classes = [EconomicTariff, EconomicTariffChangeOverTime]
    unless economic_tariff_classes.include?(@economic_tariff.class)
      raise EnergySparksUnexpectedStateException, "Economic tariff must one of #{economic_tariff_classes.join(' ')} got #{@economic_tariff.class.name}"
    end
  end

  #Loop over the accounting tariffs to select those are that marked as default (or not)
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

  # tariffs for new SMETS2 meters are often setup several days after
  # kWh data has started recording, the earlier kWh readings therefore
  # have no DCC tariff and default to default accounting tariffs
  # in this circumstance, unless overridden backdate the existing DCC tariff
  # to the start of the meter readings, so the default is no longer used
  #
  # NOTE: as n3rgy no longer hold archived tariffs, then we'll only ever have
  # the tariffs from the point that we begin loading data. So this may be more
  # common than it was before
  #
  # TODO: this could be done in the application. When the DCC tariffs or readings are loaded for a
  # meter, the start date of the tariff could be adjusted once. Or the adjustment could
  # happen when the data is loaded and past to the analytics.
  def backdate_dcc_tariffs(meter)
    return if dcc_tariffs.empty?

    if meter.amr_data.nil?
      logger.info 'Nil amr data - for benchmark/exemplar(?) dcc meter - not backdating dcc tariffs'
      return
    end

    days_gap = dcc_tariffs.first.tariff[:start_date] - meter.amr_data.start_date

    override_days = meter.meter_attributes[:backdate_tariff].first[:days] if meter.meter_attributes.key?(:backdate_tariff)

    if override_days.nil?
      dcc_tariffs.first.backdate_tariff(meter.amr_data.start_date) if days_gap.between?(1, MAX_DAYS_BACKDATE_TARIFF)
    else
      dcc_tariffs.first.backdate_tariff(dcc_tariffs.first.tariff[:start_date] - override_days)
    end
  end

  def dcc_tariffs
    @dcc_tariffs ||= @accounting_tariffs.select { |t| t.dcc? }.sort{ |a, b| a.tariff[:start_date] <=> b.tariff[:start_date]}
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

  # NOTE: we've only encountered these tariffs in the n3rgy sandbox so far
  # While our API client attempts to process them, but there's no support for them in
  # the application database (AFAICT). So only route to get this into the system currently
  # is via manual input. Might be best to revisit this and ensure we have proper end-to-end
  # support in place.
  #
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

  def constituent_meters
    # defensive just in case aggregation service doesn't set for single fuel type meter school
    if @meter.constituent_meters.nil? || @meter.constituent_meters.empty?
      [@meter]
    else
      @meter.constituent_meters
    end
  end

  def raise_and_log_error(exception, message)
    logger.info message
    raise exception, message
  end
end
