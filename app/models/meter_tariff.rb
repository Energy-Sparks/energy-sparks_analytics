class MeterTariff
  attr_reader :tariff
  def initialize(meter, tariff)
    @meter  = meter
    @tariff = tariff
  end

  def default?
    @tariff[:default] == true
  end

  def in_date_range?(date)
    date >= @tariff[:start_date] && date <= @tariff[:end_date]
  end

  def times(type)
    @tariff[:rates][type][:from]..@tariff[:rates][type][:to]
  end

  def rate(type)
    @tariff[:rates][type][:rate]
  end

  def weighted_cost(kwh_x48, type)
    weights = DateTimeHelper.weighted_x48_vector_single_range(times(type), rate(type))
    AMRData.fast_multiply_x48_x_x48(weights, kwh_x48)
  end
end

class EconomicTariff < MeterTariff
end

class AccountingTariff < EconomicTariff
  class UnexpectedRateType < StandardError; end
  def differential?(_date)
    tariff[:rates].key?(:nighttime_rate)
  end

  def costs(date, kwh_x48)
    differential = 
    if differential?(date)
      {
        rates_x48: {
          nighttime_rate:   weighted_cost(kwh_x48, :nighttime_rate),
          daytime_rate:     weighted_cost(kwh_x48, :daytime_rate),
        },
        standing_charges: standing_charges(date, kwh_x48.sum),
        differential: true
      }
    else
      {
        rates_x48: {
          flat_rate:     AMRData.fast_multiply_x48_x_scalar(kwh_x48, tariff[:rates][:rate][:rate])
        },
        standing_charges: standing_charges(date, kwh_x48.sum),
        differential: false
      }
    end
  end

  def standing_charges(date, days_kwh)
    standing_charge = {}
    tariff[:rates].each do |standing_charge_type, rate|
      next if [:rate, :daytime_rate, :nighttime_rate, :flat_rate].include?(standing_charge_type)
      standing_charge[standing_charge_type] = daily_rate(date, rate[:per], rate[:rate], days_kwh)
    end
    standing_charge
  end

  def daily_rate(date, per, rate, days_kwh)
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
      raise UnexpectedRateType, "Unexpected unit rate type for tariff #{per}"
    end
  end
end

class GenericAccountingTariff < AccountingTariff
  def differential?(_date)
    rate_types.any?{ |type| type.to_s.match(/rate[0-9]/) }
  end

  def costs(date, kwh_x48)
    if differential?(date)
      {
        rates_x48: rate_types.map { |type| [type, weighted_cost(kwh_x48, type)]}.to_h,
        standing_charges: standing_charges(date, kwh_x48.sum)
      }
    else
      {
        rates_x48: {
          flat_rate:     AMRData.fast_multiply_x48_x_scalar(kwh_x48, tariff[:rates][:flat_rate][:rate])
        },
        standing_charges: standing_charges(date, kwh_x48.sum),
        differential: true
      }
    end
  end

  def rate_types
    tariff[:rates].keys.select?{ |type| type.to_s.match(/rate[0-9]/) }
  end
end
