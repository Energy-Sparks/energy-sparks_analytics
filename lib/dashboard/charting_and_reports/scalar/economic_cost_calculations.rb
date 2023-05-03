# consolidaiton of miscellany of economic cost calculations
# used in alerts and advice
class EconomicCostCalculations
  include Singleton

  def saving_rate(type:, school: nil, kwh: nil, meter: nil, period: nil, asof_date: nil)
    case type
    when :solar_pv_deprecated
      convert_kwh_to_£_using_latest_tariff(kwh, meter, start_date, asof_date)
    else
      raise EnergySparksUnexpectedStateException, "Unknown type #{type} for #{self.class.name} calculation"
    end
  end

  private
end
