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
    new_costs = meter.meter_tariffs.economic_cost(date, kwh_halfhour_x48)

    if new_costs.key?(:flat_rate)
      [new_costs[:flat_rate], AMRData.one_day_zero_kwh_x48, {}]
    else
      [new_costs[:daytime_rate], new_costs[:nighttime_rate], {}]
    end
  end

  # accounting tariffs come in least to most specific order
  # we want the most specific matching one first
  def self.accounting_tariff_for_date(date, meter)
    meter.meter_tariffs.accounting_tariff_for_date(date)&.tariff
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
        missing_meter_stats[meter.mpan_mprn][:days_tariffs] += 1 unless tariff.nil? || tariff[:default] == true
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
    new_tariff = meter.meter_tariffs.accounting_tariff_for_date(date)

    [costs[:daytime_rate], costs[:nighttime_rate], costs[:standing_charges]]
  end

  # to support an optmisation in the aggregation service for combined meters
  # avoid the need to non-parameterised aggregate economic costs data if there are
  # no differential tariffs in the given date range for any of its underlying meters
  # the aggregattion service interates through the component meters to check 'if any' are differential
  # calling this for each component meter, not the combined meter
  def self.differential_tariff_in_date_range?(meter, start_date, end_date)
    meter.meter_tariffs.any_differential_tariff?(start_date, end_date)
  end
end
