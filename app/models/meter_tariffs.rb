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
    tariff_config = economic_tariff_config(mpan_mprn, date, fuel_type)

    daytime_cost_x48, nighttime_cost_x48 = day_night_costs_x48(tariff_config, kwh_halfhour_x48)

    [daytime_cost_x48, nighttime_cost_x48, {}] # {} = the standing charges for consistancy with the accounting tariff interface
  end

  def self.accounting_tariff_x48(date, mpan_mprn, fuel_type, kwh_halfhour_x48, default_energy_purchaser)
    tariff_config = tariff_for_date(METER_TARIFFS, mpan_mprn, date)

    tariff_config = default_area_tariff_for_date(default_energy_purchaser, fuel_type, date) if tariff_config.nil?

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
    when :kwh # treat these as day only rates for the moment TODO(PH, 8Apr2019), should perhaps be intraday?
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

  private_class_method def self.tariff_for_date(date, tariff_config)
    tariff_config.select { |date_range, _tariff| date_range == date }
    return tariff_config.values[0] if tariff_config.length == 1
    raise EnergySparksNotEnoughDataException.new("No tariff information available for date #{date}")
    raise EnergySparksNotEnoughDataException.new("To many tariffs (#{tariff_config.length}) for date #{date}")
  end

  private_class_method def self.economic_tariff_config(mpan_mprn, date, fuel_type)
    tariff_type = fuel_type
    # use accounting tariff's to determine whether meter has a differential tariff
    tariff_type = :electricity_differential if tariff_type == :electricity && differential_meter?(mpan_mprn, date)
    tariff_for_date(ECONOMIC_TARIFFS, tariff_type, date)
  end

  private_class_method def self.default_area_tariff_for_date(area_name, fuel_type, date)
    raise EnergySparksNotEnoughDataException.new("Missing default area meter tariff data for #{area_name} #{fuel_type}") if DEFAULT_ACCOUNTING_TARIFFS.dig(area_name, fuel_type).nil?
    DEFAULT_ACCOUNTING_TARIFFS[area_name][fuel_type]
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
