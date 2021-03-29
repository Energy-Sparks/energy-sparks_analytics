require_relative '../../lib/dashboard/time_of_year.rb'
require_relative '../../lib/dashboard/time_of_day.rb'
require 'amazing_print'
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

  def self.economic_tariff_x48(date, meter, kwh_halfhour_x48)
    tariff_config = meter.attributes(:economic_tariff)
=begin
puts "Got here eco tariff for #{meter.mpan_mprn} is #{!tariff_config.nil?} #{date}"
puts Thread.current.backtrace if meter.mpan_mprn == 80000000106982
exit if meter.mpan_mprn == 80000000106982
=end
    daytime_cost_x48, nighttime_cost_x48 = day_night_costs_x48(tariff_config, kwh_halfhour_x48, differential_meter?(date, meter))

    [daytime_cost_x48, nighttime_cost_x48, {}] # {} = the standing charges for consistancy with the accounting tariff interface
  end

  # accounting tariffs come in least to most specific order
  # we want the most specific matching one first
  def self.accounting_tariff_for_date(date, meter)
    choose_an_accounting_tariff(date, meter)
  end

  private_class_method def self.choose_an_accounting_tariff(date, meter)
    tariffs = [meter.attributes(:accounting_tariffs), meter.attributes(:accounting_tariff_generic)].compact.flatten
    tariffs.select { |tariff| date >= tariff[:start_date] && date <= tariff[:end_date] }.last
  end

  # stats for rating adult dashboard costs pages, by availability of accounting tariff data
  def self.accounting_tariff_availability_statistics(start_date, end_date, meters)
    missing_meter_stats = Hash.new{ |hash, key| hash[key] = { days_tariffs: 0, days_data: 0 } }
    meters.each do |meter|
      # some meters may not extent over period of aggregate if deprecated
      start_date = meter.amr_data.start_date if start_date < meter.amr_data.start_date
      end_date   = meter.amr_data.end_date   if end_date < meter.amr_data.end_date
      (start_date..end_date).each do |date|
        tariff = accounting_tariff_for_date(date, meter)
        missing_meter_stats[meter.mpan_mprn][:days_data] += 1
        missing_meter_stats[meter.mpan_mprn][:days_tariffs] += 1 unless tariff.nil? || tariff[:default]
      end
    end
    missing_meter_stats
  end

  def self.accounting_tariffs_available_for_period?(start_date, end_date, meters)
    meters.each do |meter|
      # some meters may not extent over period of aggregate if deprecated
      start_date = meter.amr_data.start_date if start_date < meter.amr_data.start_date
      end_date   = meter.amr_data.end_date   if end_date < meter.amr_data.end_date
      (start_date..end_date).each do |date|
        return false if accounting_tariff_for_date(date, meter).nil?
      end
    end
    true
  end

  def self.accounting_tariff_availability_coverage(start_date, end_date, meters)
    stats = accounting_tariff_availability_statistics(start_date, end_date, meters)
    # can't use sum directly because of Ruby lib statssample sum issue
    days_data = stats.values.map{ |meter_stats| meter_stats[:days_data] }
    days_tariffs = stats.values.map{ |meter_stats| meter_stats[:days_tariffs] }
    (days_tariffs.sum / days_data.sum).to_f
  end


  def self.accounting_tariff_x48(date, meter, kwh_halfhour_x48)
    tariff_config = accounting_tariff_for_date(date, meter)

    tariff_config = default_accounting_tariff_in_event_of_no_others(date, meter) if tariff_config.nil?

    raise EnergySparksNotEnoughDataException.new("Missing tariff data for #{meter.mpan_mprn} on #{date}") if tariff_config.nil?

    daytime_cost_x48, nighttime_cost_x48 = day_night_costs_x48(tariff_config, kwh_halfhour_x48, differential_tariff?(tariff_config))

    standing_charge = standing_charges(date, tariff_config, kwh_halfhour_x48.sum)

    [daytime_cost_x48, nighttime_cost_x48, standing_charge]
  end

  private_class_method def self.day_night_costs_x48(tariff_config, kwh_halfhour_x48, differential)
    daytime_cost_x48 = nil
    nighttime_cost_x48 = nil

    if differential
      daytime_cost_x48, nighttime_cost_x48 = differential_tariff_cost(tariff_config, kwh_halfhour_x48)
    else
      rate_key = flat_rate_key_name(tariff_config)
      daytime_cost_x48 = AMRData.fast_multiply_x48_x_scalar(kwh_halfhour_x48, tariff_config[:rates][rate_key][:rate])
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
    daytime_rate_key, daytime_rate_key = differential_key_name(tariff_config)
    daytime_costs   = weighted_costs(tariff_config, kwh_halfhour_x48, daytime_rate_key)
    nighttime_costs = weighted_costs(tariff_config, kwh_halfhour_x48, daytime_rate_key)
    # AMRData.fast_add_x48_x_x48(daytime_costs, nighttime_costs)
    [daytime_costs, nighttime_costs]
  end

  private_class_method def self.weighted_costs(tariff_config, kwh_halfhour_x48, rate_type)
    daytime_time_weights = DateTimeHelper.weighted_x48_vector_single_range(
      tariff_config[:rates][rate_type][:from]..tariff_config[:rates][rate_type][:to],
      tariff_config[:rates][rate_type][:rate]
    )
    AMRData.fast_multiply_x48_x_x48(daytime_time_weights, kwh_halfhour_x48)
  end

  # to support an optmisation in the aggregation service for combined meters
  # avoid the need to non-parameterised aggregate economic costs data if there are
  # no differential tariffs in the given date range for any of its underlying meters
  # the aggregattion service interates through the component meters to check 'if any' are differential
  # calling this for each component meter, not the combined meter
  def self.differential_tariff_in_date_range?(meter, start_date, end_date)
    tariffs = meter.attributes(:accounting_tariffs) || []
    return false if tariffs.empty? # we have no information for this meter, so assume non differential
    tariffs.each do |tariff_config|
      in_range = date_ranges_overlap(tariff_config[:start_date], tariff_config[:end_date], start_date, end_date)
      return true if in_range && differential_tariff?(tariff_config)
    end
    false
  end


  # test explicitly rather than ruby .overlap? function as it has potential
  # to slowly iterate through each range rather than testing boundary conditions
  private_class_method def self.date_ranges_overlap(date_range_1_start, date_range_1_end, date_range_2_start, date_range_2_end)
    # think clearer on 3 lines:
    return false if date_range_1_end < date_range_2_start # range 1 occurs before range 2
    return false if date_range_1_start > date_range_2_end  # range 1 occurs after  range 2
    return true                                              # otherwise there must be an overlap
  end

  private_class_method def self.default_accounting_tariff_in_event_of_no_others(date, meter)
    unless %i[solar_pv exported_solar_pv].include?(meter.fuel_type)
      Logging.logger.error "Error: unable to get accounting tariff for date #{date} and fuel #{meter.fuel_type}"
    end
    meter.attributes(:economic_tariff)
  end

  private_class_method def self.differential_meter?(date, meter)
    tariff_config = accounting_tariff_for_date(date, meter)
    tariff_config.nil? ? false : differential_tariff?(tariff_config)
  end

  private_class_method def self.differential_tariff?(tariff_config)
    tariff_config[:rates][:nighttime_rate] || generic_tariff?(tariff_config)
  end

  private_class_method def self.generic_tariff?(tariff_config)
    tariff_config[:rates].keys.any?{ |type| type.to_s.match(/rate[0-9]/) }
  end

  private_class_method def self.flat_rate_key_name(tariff_config)
    if tariff_config.dig(:rates, :rate, :rate)
      :rate
    elsif tariff_config.dig(:rates, :flat_rate, :rate)
      :flat_rate
    else
      raise EnergySparksUnexpectedStateException, 'Flat rate not configured?'
    end
  end

  private_class_method def self.differential_key_name(tariff_config)
    daytime_rate_key = generic_tariff?(tariff_config) ? :rate1 : :daytime_rate
    night_time_rate_key = generic_tariff?(tariff_config) ? :rate0 : :nighttime_rate
    [daytime_rate_key, daytime_rate_key]
  end
end
