class GenericTariffManager
  include Logging

  def initialize(meter)
    @meter = meter
    @meter_tariffs = []
    @school_tariffs = []
    @school_group_tariffs = []
    @system_tariffs = []
    @list_of_all_tariffs =[@meter_tariffs, @school_tariffs, @school_group_tariffs, @system_tariffs]
    pre_process_tariff_attributes
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

  #TODO this should be moved elsewhere, similar to AccountingTariff
  #TODO exceptions?
  def economic_cost(date, kwh_x48)
    tariff = find_tariff_for_date(date)
    #TODO this is different to original?
    return nil unless tariff
    #TODO borrowed from generic accounting tariff
    t = if tariff.flat_tariff?(date)
        {
          rates_x48: {
            MeterTariff::FLAT_RATE => AMRData.fast_multiply_x48_x_scalar(kwh_x48, tariff.tariff[:rates][:flat_rate][:rate])
          },
          differential: false
        }
      else
        {
          rates_x48: tariff.tariff.rate_types.map { |type| tariff.weighted_costs(kwh_x48, type)}.inject(:merge),
          differential: true
        }
      end

    t.merge( { standing_charges: {}, system_wide: true, default: true } )
  end

  #TODO this will not return exactly same structure, e.g. no system/default values
  def accounting_cost(date, kwh_x48)
    tariff = find_tariff_for_date(date)
    return nil if tariff.nil?
    tariff.costs(date, kwh_x48)
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
  end

end
