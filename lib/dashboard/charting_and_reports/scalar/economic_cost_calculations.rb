# consolidaiton of miscellany of economic cost calculations
# used in alerts and advice
class EconomicCostCalculations
  include Singleton

  def saving_rate(type:, school: nil, kwh: nil, meter: nil, period: nil)
    case type
    when :peak_kw
      convert_peak_electricity_kwh_to_£(kwh, meter)
    else
      raise EnergySparksUnexpectedStateException, "Unknown type #{type} for #{self.class.name} calculation"
    end
  end

  private

  # convert at midday rate for most recent tariff
  # to capture differential rate at peak times
  def convert_peak_electricity_kwh_to_£(kwh, meter)
    peak_rate_£_per_kwh = meter.amr_data.economic_cost_for_x48_kwhs(meter.amr_data.end_date, peak_4_hours_of_day_x48_sum_to_1)
    kwh * peak_rate_£_per_kwh
  end

  def peak_4_hours_of_day_x48_sum_to_1
    hh_count_4_hours = 8
    remainder_hh_count = 48 - hh_count_4_hours
    [
      Array.new(remainder_hh_count / 2, 0.0),
      Array.new(hh_count_4_hours,       1.0 / hh_count_4_hours),
      Array.new(remainder_hh_count / 2, 0.0)
    ].flatten
  end
end
