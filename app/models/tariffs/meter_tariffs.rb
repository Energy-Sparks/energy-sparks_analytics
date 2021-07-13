require_relative '../../../lib/dashboard/time_of_year.rb'
require_relative '../../../lib/dashboard/time_of_day.rb'
require 'amazing_print'
require 'date'
# economic and accounting tariff configuration and setup
# designed to be called and precalculated at the end of the
# aggregation service process
# economic tariffs: are used for estimating the economic benefit of
#                   an energy efficiency investment decision or
#                   more simplistically for education purposes
#                   as there are no standing charges and the values
#                   are typically round figures e.g. 15p/kWh and 3p/kWh
#                   the economic tariff do however rely on the 'accounting
#                   tariffs' to determine whether the electricity is on a
#                   differential (economy 7) tariff
# accounting tariffs: what the school should be paying in their bills
#                   includes the standing and other charges
#                   and can vary over time with new energy contracts
class MeterTariffs
  extend Logging

  # stats for rating adult dashboard costs pages, by availability of accounting tariff data
  def self.accounting_tariff_availability_statistics(start_date, end_date, meters)
    missing_meter_stats = Hash.new{ |hash, key| hash[key] = { days_tariffs: 0, days_data: 0 } }
    meters.each do |meter|
      # some meters may not extent over period of aggregate if deprecated
      start_date = meter.amr_data.start_date if start_date < meter.amr_data.start_date
      end_date   = meter.amr_data.end_date   if end_date < meter.amr_data.end_date
      (start_date..end_date).each do |date|
        tariff = meter.meter_tariffs.accounting_tariff_for_date(date)&.tariff
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
        return false if meter.meter_tariffs.accounting_tariff_for_date(date)&.tariff.nil?
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
end
