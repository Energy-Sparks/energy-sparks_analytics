require_relative '../../lib/dashboard/time_of_year.rb'
require_relative '../../lib/dashboard/time_of_day.rb'
require 'awesome_print'
require 'date'
# economic and accounting tariff configuration and setup
# designed to be called and precalculated at the end of the
# aggregation service process
# economic tariffs: are used for estimating the economic benefit of
#                   an energy efficiency investment decision or
#                   more simplistically for education purposes
#                   as there are no standing charges and the values
#                   are typically round figures e.g. 12p/kWh and 3p/kWh
#                   the economic tariff do however rely on the 'accounting
#                   tariffs' to determine whether the electricity is on a
#                   differential (economy 7) tariff
# accounting tariffs: what the school should be paying in their bills
#                   includes the standing and other charges
#                   and can vary over time with new energy contracts
# potentially should be Singleton class?
class MeterTariffs
  extend Logging

  def self.economic_tariff_x48(date, mpan_mprn, fuel_type, kwh_halfhour_x48)
    # TODO(PH, 5May19) - analystics meta data load means strange fuel types are filtering through, remove on reorg of meta data loader
    fuel_type = :electricity if fuel_type == :aggregated_electricity
    tariff_config = economic_tariff_config(mpan_mprn, date, fuel_type)

    daytime_cost_x48, nighttime_cost_x48 = day_night_costs_x48(tariff_config, kwh_halfhour_x48)

    [daytime_cost_x48, nighttime_cost_x48, {}] # {} = the standing charges for consistancy with the accounting tariff interface
  end

  def self.accounting_tariff_for_date(date, mpan_mprn)
    tariff_for_date(METER_TARIFFS, mpan_mprn, date)
  end

  def self.accounting_tariff_x48(date, mpan_mprn, fuel_type, kwh_halfhour_x48, default_energy_purchaser)
    tariff_config = tariff_for_date(METER_TARIFFS, mpan_mprn, date)

    tariff_config = default_area_tariff_for_date(default_energy_purchaser, fuel_type, date) if tariff_config.nil?

    tariff_config = default_accounting_tariff_in_event_of_no_others(date, fuel_type) if tariff_config.nil?

    daytime_cost_x48, nighttime_cost_x48 = day_night_costs_x48(tariff_config, kwh_halfhour_x48)

    standing_charge = standing_charges(date, tariff_config, kwh_halfhour_x48.sum)

    [daytime_cost_x48, nighttime_cost_x48, standing_charge]
  end

  private_class_method def self.day_night_costs_x48(tariff_config, kwh_halfhour_x48)
    daytime_cost_x48 = nil
    nighttime_cost_x48 = nil

    if differential_tariff?(tariff_config)
      daytime_cost_x48, nighttime_cost_x48 = differential_tariff_cost(tariff_config, kwh_halfhour_x48)
    else
      daytime_cost_x48 = AMRData.fast_multiply_x48_x_scalar(kwh_halfhour_x48, tariff_config[:rates][:rate][:rate])
    end
    [daytime_cost_x48, nighttime_cost_x48]
  end

  private_class_method def self.standing_charges(date, tariff_config, days_kwh)
    standing_charge = {}
    tariff_config[:rates].each do |standing_charge_type, rate|
      next if [:rate, :daytime_rate, :nighttime_rate].include?(standing_charge_type)
      standing_charge[standing_charge_type] = daily_rate(date, rate[:per], rate[:rate], days_kwh)
    end
    standing_charge
  end

  private_class_method def self.daily_rate(date, per, rate, days_kwh)
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
      raise EnergySparksUnexpectedSchoolDataConfiguration.new("Unexpected unit rate type for tariff #{per}")
    end
  end

  # multiply the 'economy 7' tariffs for the relevant time of day by the kwh values
  private_class_method def self.differential_tariff_cost(tariff_config, kwh_halfhour_x48)
    daytime_costs = weighted_costs(tariff_config, kwh_halfhour_x48, :daytime_rate)
    nighttime_costs = weighted_costs(tariff_config, kwh_halfhour_x48, :nighttime_rate)
    # AMRData.fast_add_x48_x_x48(daytime_costs, nighttime_costs)
    [daytime_costs, nighttime_costs]
  end

  private_class_method def self.weighted_costs(tariff_config, kwh_halfhour_x48, rate_type)
    daytime_time_weights = DateTimeHelper.weighted_x48_vector_single_range(
      tariff_config[:rates][rate_type][:time_period],
      tariff_config[:rates][rate_type][:rate]
    )
    AMRData.fast_multiply_x48_x_x48(daytime_time_weights, kwh_halfhour_x48)
  end

  # to support an optmisation in the aggregation service for combined meters
  # avoid the need to non-parameterised aggregate economic costs data if there are
  # no differential tariffs in the given date range for any of its underlying meters
  # the aggregattion service interates through the component meters to check 'if any' are differential
  # calling this for each component meter, not the combined meter
  def self.differential_tariff_in_date_range?(mpan_mprn, start_date, end_date)
    return false unless METER_TARIFFS.key?(mpan_mprn) # we have no information for this meter, so assume non differential
    aggregate_meter_date_range = Range.new(start_date, end_date)
    METER_TARIFFS[mpan_mprn].each do |tariff_date_range, tariff_config|
      in_range = date_ranges_overlap(tariff_date_range, aggregate_meter_date_range)
      return true if differential_tariff?(tariff_config) && in_range
    end
    false
  end

  # test explicitly rather than ruby .overlap? function as it has potential
  # to slowly iterate through each range rather than testing boundary conditions
  private_class_method def self.date_ranges_overlap(date_range_1, date_range_2)
    # think clearer on 3 lines:
    return false if date_range_1.last  < date_range_2.first # range 1 occurs before range 2
    return false if date_range_1.first > date_range_2.last  # range 1 occurs after  range 2
    return true                                              # otherwise there must be an overlap
  end

=begin
  private_class_method def self.tariff_for_date(date, tariff_config)
    tariff_config.select { |date_range, _tariff| date_range == date }
    return tariff_config.values[0] if tariff_config.length == 1
    raise EnergySparksNotEnoughDataException.new("No tariff information available for date #{date}")
    raise EnergySparksNotEnoughDataException.new("To many tariffs (#{tariff_config.length}) for date #{date}")
  end
=end

  private_class_method def self.economic_tariff_config(mpan_mprn, date, fuel_type)
    tariff_type = fuel_type
    # use accounting tariff's to determine whether meter has a differential tariff
    tariff_type = :electricity_differential if tariff_type == :electricity && differential_meter?(mpan_mprn, date)
    tariff_for_date(ECONOMIC_TARIFFS, tariff_type, date)
  end

  # short term adjustment for difference in area names between analystics and front end TODO(All, 9Apr2019) resolve long term
  private_class_method def self.translate_area_names_from_front_end(area_name)
    # rather not use include? as i may clash with other Bath school groups on different tariffs?
    area_name == 'Bath & North East Somerset' ? 'Bath' : area_name
  end

  private_class_method def self.default_area_tariff_for_date(area_name, fuel_type, date)
    area_name = translate_area_names_from_front_end(area_name)
    raise EnergySparksNotEnoughDataException.new("Missing default area meter tariff data for #{area_name} #{fuel_type}") if DEFAULT_ACCOUNTING_TARIFFS.dig(area_name, fuel_type).nil?
    tariff_for_date(DEFAULT_ACCOUNTING_TARIFFS[area_name], fuel_type, date)
  end

  private_class_method def self.default_accounting_tariff_in_event_of_no_others(date, fuel_type)
    Logging.logger.error "Error: unable to get accounting tariff for date #{date} and fuel #{fuel_type}"
    tariff_for_date(ECONOMIC_TARIFFS, fuel_type, date)
  end

  private_class_method def self.tariff_for_date(tariff_group, identifier, date)
    return nil unless tariff_group.key?(identifier)
    tariff = tariff_group[identifier].select { |date_range, _tariff| date >= date_range.first && date <= date_range.last }
    return nil if tariff.empty?
    raise EnergySparksUnexpectedSchoolDataConfiguration.new("Only expecting one tariff for date #{date}, got #{tariff.length}") if tariff.length > 1
    tariff.values[0]
  end

  private_class_method def self.differential_meter?(mpan_mprn, date)
    tariff_config = tariff_for_date(METER_TARIFFS, mpan_mprn, date)
    tariff_config.nil? ? false : differential_tariff?(tariff_config)
  end

  private_class_method def self.differential_tariff?(tariff_config)
    tariff_config[:rates].key?(:nighttime_rate)
  end
end
