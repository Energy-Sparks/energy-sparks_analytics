class GenericTariffManager
  include Logging
  MAX_DAYS_BACKDATE_TARIFF = 30

  attr_reader :meter_tariffs, :school_tariffs, :school_group_tariffs, :system_tariffs

  def initialize(meter)
    @meter = meter
    @meter_tariffs = []
    @school_tariffs = []
    @school_group_tariffs = []
    @system_tariffs = []
    @list_of_all_tariffs =[@meter_tariffs, @school_tariffs, @school_group_tariffs, @system_tariffs]
    pre_process_tariff_attributes
    backdate_dcc_tariffs(meter)
  end

  def find_tariff_for_date(date)
    found_tariffs = nil
    @list_of_all_tariffs.each do |list|
      found_tariffs = search_tariffs(list, date)
      break if found_tariffs.any?
    end
    return nil unless found_tariffs.any?
    sort_by_most_recent(found_tariffs).first
  end

  #TODO exceptions?
  def economic_cost(date, kwh_x48)
    tariff = find_tariff_for_date(date)&.economic_costs(date, kwh_x48)
  end

  def accounting_cost(date, kwh_x48)
    tariff = find_tariff_for_date(date)&.costs(date, kwh_x48)
  end

  def any_differential_tariff?(start_date, end_date)
  end

  def accounting_tariff_for_date(date)
  end

  def economic_tariffs_change_over_time?
  end

  def last_tariff_change_date(start_date = @meter.amr_data.start_date, end_date = @meter.amr_data.end_date)
  end

  def tariff_change_dates_in_period(start_date  = @meter.amr_data.start_date, end_date = @meter.amr_data.end_date)
  end

  def meter_tariffs_differ_within_date_range?(start_date, end_date)
  end

  def meter_tariffs_changes_between_periods?(period1, period2)
  end

  private

  def search_tariffs(list, date)
    list.select { |accounting_tariff| accounting_tariff.in_date_range?(date) }
  end

  #sort list of found tariffs with most recently created first,
  #force nil timestamps to sort last
  def sort_by_most_recent(found_tariffs)
    found_tariffs.sort do |a,b|
      a_created = a.tariff[:created_at]
      b_created = b.tariff[:created_at]
      a_created && b_created ? b_created <=> a_created : a_created ? -1 : 1
    end
  end

  def tariff_attributes
    @meter.attributes(:accounting_tariff_generic)
  end

  def pre_process_tariff_attributes
    return if tariff_attributes.nil?
    #sort the attributes into separate bins based on tariff_holder
    #within each bin, sort by created_at, newest first
    tariff_attributes.each do |attribute|
      tariff = GenericAccountingTariff.new(@meter, attribute)
      case attribute[:tariff_holder]
      when :meter
        @meter_tariffs << tariff
      when :school
        @school_tariffs << tariff
      when :school_group
        @school_group_tariffs << tariff
      when :site_settings
        @system_tariffs << tariff
      else
        raise "Unknown tariff holder type"
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
      return if @meter_tariffs.empty? || dcc_tariffs.empty?

      #if meter.amr_data.nil?
      #  logger.info 'Nil amr data - for benchmark/exemplar(?) dcc meter - not backdating dcc tariffs'
      #  return
      #end

      days_gap = dcc_tariffs.first.tariff[:start_date] - meter.amr_data.start_date

      override_days = meter.meter_attributes[:backdate_tariff].first[:days] if meter.meter_attributes.key?(:backdate_tariff)

      if override_days.nil?
        dcc_tariffs.first.backdate_tariff(meter.amr_data.start_date) if days_gap.between?(1, MAX_DAYS_BACKDATE_TARIFF)
      else
        dcc_tariffs.first.backdate_tariff(dcc_tariffs.first.tariff[:start_date] - override_days)
      end
    end

    def dcc_tariffs
      @dcc_tariffs ||= @meter_tariffs.select { |t| t.dcc? }.sort{ |a, b| a.tariff[:start_date] <=> b.tariff[:start_date]}
    end
  end
end
