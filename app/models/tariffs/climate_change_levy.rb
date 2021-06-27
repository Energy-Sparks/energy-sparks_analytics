require 'date'

class ClimateChangeLevy
  class MissingClimateChangeLevyData < StandardError; end

  # https://www.gov.uk/guidance/climate-change-levy-rates
  DEFAULT_RATES = {
    electricity: {
      Date.new(2018, 4, 1)..Date.new(2019, 3, 31) => 0.00583,
      Date.new(2019, 4, 1)..Date.new(2020, 3, 31) => 0.00847,
      Date.new(2020, 4, 1)..Date.new(2021, 3, 31) => 0.00811,
      Date.new(2021, 4, 1)..Date.new(2022, 3, 31) => 0.00775,
    },
    gas: {
      Date.new(2018, 4, 1)..Date.new(2019, 3, 31) => 0.00203,
      Date.new(2019, 4, 1)..Date.new(2020, 3, 31) => 0.00339,
      Date.new(2020, 4, 1)..Date.new(2021, 3, 31) => 0.00406,
      Date.new(2021, 4, 1)..Date.new(2022, 3, 31) => 0.00465,
    }
  }

  def self.rate(fuel_type, date)
    check_levy_set(fuel_type, date)
    
    rate_range = DEFAULT_RATES[fuel_type].select do |date_range, _rate|
      # much faster than ruby matching as by default it scans the date range incrementally
      date >= date_range.first && date <= date_range.last
    end

    if rate_range.nil? || rate_range.empty?
      [:climate_change_levy, 0.0]
    else
      [ccl_key(rate_range.keys[0]), rate_range.values[0]]
    end
  end

  def self.keyed_rates_within_date_range(fuel_type, start_date, end_date)
    rates = rates_within_date_range(fuel_type, start_date, end_date)
    rates.transform_keys { |date_range| ccl_key(date_range) }
  end
  
  private_class_method def self.rates_within_date_range(fuel_type, start_date, end_date)
    DEFAULT_RATES[fuel_type].select do |date_range, _rate|
      (start_date >= date_range.first && start_date <= date_range.last) ||
      (end_date   >= date_range.first && end_date   <= date_range.last)
    end
  end

  private_class_method def self.ccl_key(date_range)
    start_year = date_range.first.strftime('%Y')
    end_year   = date_range.last.strftime('%y')
    key = "climate_change_levy_(#{start_year}-#{end_year})".to_sym
  end

  private_class_method def self.check_levy_set(fuel_type, date)
    if date > DEFAULT_RATES[fuel_type].keys.map(&:last).max
      raise MissingClimateChangeLevyData, "Internal Error: climate change levy not set for #{date}"
    end
  end
end