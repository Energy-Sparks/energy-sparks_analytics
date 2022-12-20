# benchmark metrics
#
module BenchmarkMetrics
  ELECTRICITY_PRICE = 0.15
  SOLAR_EXPORT_PRICE = 0.05
  GAS_PRICE = 0.03
  OIL_PRICE = 0.05
  PERCENT_ELECTRICITY_OUT_OF_HOURS_BENCHMARK = 0.3
  PERCENT_GAS_OUT_OF_HOURS_BENCHMARK = 0.3
  PERCENT_STORAGE_HEATER_OUT_OF_HOURS_BENCHMARK = 0.2
  BENCHMARK_ELECTRICITY_USAGE_PER_PUPIL = 50_000.0 / 200.0
  RATIO_PRIMARY_TO_SECONDARY_ELECTRICITY_USAGE = 1.3 # secondary electricity usage typically 1.3 times higher due extra hours and server ICT
  BENCHMARK_ELECTRICITY_USAGE_PER_M2 = 50_000.0 / 1_200.0
  BENCHMARK_GAS_USAGE_PER_PUPIL = 0.9 * 115_000.0 / 200.0 # 0.9 is artificial incentive for schools to do better
  BENCHMARK_GAS_USAGE_PER_M2 = 0.9 * 115_000.0 / 1_200.0 # 0.9 is artificial incentive for schools to do better
  EXEMPLAR_GAS_USAGE_PER_M2 = 80.0
  EXEMPLAR_ELECTRICITY_USAGE_PER_PUPIL = 175
  BENCHMARK_ELECTRICITY_PEAK_USAGE_KW_PER_M2 = 0.01
  LONG_TERM_ELECTRICITY_CO2_KG_PER_KWH = 0.15
  ANNUAL_AVERAGE_DEGREE_DAYS = 2000.0
  AVERAGE_GAS_PROPORTION_OF_HEATING = 0.6

  # BENCHMARK_ENERGY_COST_PER_PUPIL = BENCHMARK_GAS_USAGE_PER_PUPIL * GAS_PRICE +
  #                                  BENCHMARK_ELECTRICITY_USAGE_PER_PUPIL * ELECTRICITY_PRICE

  # number less than 1.0 for colder area, > 1.0 for milder areas
  # multiply by this number if normalising school to other schools in different regions
  # divide by this number if scaling a central UK wide benchmark to a school
  def self.normalise_degree_days(regional_temperatures, _holidays, fuel_type, asof_date)
    regional_degree_days = regional_temperatures.degree_days_this_year(asof_date)
    if fuel_type == :gas
      scale_percent_towards_1(ANNUAL_AVERAGE_DEGREE_DAYS / regional_degree_days, AVERAGE_GAS_PROPORTION_OF_HEATING)
    elsif fuel_type == :electricity || fuel_type == :storage_heaters
      ANNUAL_AVERAGE_DEGREE_DAYS / regional_degree_days
    else
      raise EnergySparksUnexpectedStateException, "Not expecting fuel type #{fuel_type} for degree day adjustment"
    end
  end

  # p = 110%, s = 60% => 106%
  def self.scale_percent_towards_1(percent, scale)
    ((percent - 1.0) * scale) + 1.0
  end

  def self.benchmark_energy_usage_£_per_pupil(benchmark_type, school, asof_date, list_of_fuels)

    total = 0.0

    if list_of_fuels.include?(:electricity)
      total += benchmark_electricity_usage_£_per_pupil(benchmark_type, school)
    end

    if !(list_of_fuels & %i[gas storage_heater storage_heaters]).empty?
      total += benchmark_heating_usage_£_per_pupil(benchmark_type, school, asof_date)
    end

    total
  end

  def self.benchmark_electricity_usage_£_per_pupil(benchmark_type, school)
    benchmark_electricity_usage_kwh_per_pupil(benchmark_type, school) * electricity_price_£_per_kwh(school)
  end

  def self.electricity_price_£_per_kwh(school)
    school.aggregated_electricity_meters.amr_data.blended_rate(:kwh, :£)
  end

  def self.gas_price_£_per_kwh(school)
    school.aggregated_heat_meters.amr_data.blended_rate(:kwh, :£)
  end

  # scale benchmark to schools's temperature zone; so result if higher for
  # Scotland and lower for SW UK
  # also scales years, so all years normalised to same temperature
  def self.benchmark_heating_usage_kwh_per_pupil(benchmark_type, school, asof_date = nil)
    dd_adj = normalise_degree_days(school.temperatures, school.holidays, :gas, asof_date)
    if benchmark_type == :benchmark
      BENCHMARK_GAS_USAGE_PER_PUPIL / dd_adj
    else # :exemplar
      EXEMPLAR_GAS_USAGE_PER_M2 / dd_adj
    end
  end

  # as above, larger number returned for Scotland, lower for SW
  def self.benchmark_heating_usage_£_per_pupil(benchmark_type, school, asof_date = nil)
    benchmark_heating_usage_kwh_per_pupil(benchmark_type, school, asof_date) * gas_price_£_per_kwh(school)
  end

  def self.benchmark_electricity_usage_kwh_per_pupil(benchmark_type, school)
    if benchmark_type == :benchmark
      benchmark_annual_electricity_usage_kwh(school.school_type)
    else  # :exemplar
      exemplar_annual_electricity_usage_kwh(school.school_type)
    end
  end

  def self.benchmark_annual_electricity_usage_kwh(school_type, pupils = 1)
    school_type = school_type.to_sym if school_type.instance_of? String
    check_school_type(school_type, 'benchmark electricity usage per pupil')

    case school_type
    when :primary, :infant, :junior, :special, :middle, :mixed_primary_and_secondary
      BENCHMARK_ELECTRICITY_USAGE_PER_PUPIL * pupils
    when :secondary
      RATIO_PRIMARY_TO_SECONDARY_ELECTRICITY_USAGE * BENCHMARK_ELECTRICITY_USAGE_PER_PUPIL * pupils
    end
  end

  def self.exemplar_£(school, fuel_type, start_date, end_date)
    case fuel_type
    when :electricity, :storage_heater, :storage_heaters
      exemplar_kwh(school, fuel_type, start_date, end_date) * electricity_price_£_per_kwh(school)
    when :gas
      exemplar_kwh(school, fuel_type, start_date, end_date) * gas_price_£_per_kwh(school)
    end
  end

  def self.exemplar_kwh(school, fuel_type, start_date, end_date)
    case fuel_type
    when :electricity, :storage_heater, :storage_heaters
      number_of_pupils = school.aggregated_electricity_meters.meter_number_of_pupils(school, start_date, end_date)
      BenchmarkMetrics.exemplar_annual_electricity_usage_kwh(school.school_type, number_of_pupils)
    when :gas
      floor_area = school.aggregated_heat_meters.meter_floor_area(school, start_date, end_date)
      BenchmarkMetrics::EXEMPLAR_GAS_USAGE_PER_M2 * floor_area
    end
  end

  def self.exemplar_annual_electricity_usage_kwh(school_type, pupils = 1)
    school_type = school_type.to_sym if school_type.instance_of? String
    check_school_type(school_type, 'benchmark electricity usage per pupil')

    case school_type
    when :primary, :infant, :junior, :special, :middle, :mixed_primary_and_secondary
      EXEMPLAR_ELECTRICITY_USAGE_PER_PUPIL * pupils
    when :secondary
      RATIO_PRIMARY_TO_SECONDARY_ELECTRICITY_USAGE * EXEMPLAR_ELECTRICITY_USAGE_PER_PUPIL * pupils
    end
  end

  def self.recommended_baseload_for_pupils(pupils, school_type)
    school_type = school_type.to_sym if school_type.instance_of? String
    check_school_type(school_type)

    case school_type
    when :primary, :infant, :junior, :special
      if pupils < 150
        1.5
      elsif pupils < 300
        2.5
      else
        2.5 * (pupils / 300)
      end
    when :secondary, :middle, :mixed_primary_and_secondary
      if pupils < 400
        10
      else
        10 + 10 * (pupils - 400) / 400
      end
    end
  end

  private_class_method def self.check_school_type(school_type, type = 'baseload benckmark')
    raise EnergySparksUnexpectedStateException.new("Nil type of school in #{type} request") if school_type.nil?
    if !%i[primary infant junior special middle secondary mixed_primary_and_secondary].include?(school_type)
      raise EnergySparksUnexpectedStateException.new("Unknown type of school #{school_type} in #{type} request")
    end
  end

  def self.exemplar_baseload_for_pupils(pupils, school_type)
    # arbitrarily 60% for the moment TODO(PH, 11Apr2019)
    0.6 * recommended_baseload_for_pupils(pupils, school_type)
  end

  def self.typical_servers_for_pupils(school_type, pupils)
    school_type = school_type.to_sym if school_type.instance_of? String
    servers = 1
    power = 500.0
    case school_type
    when :primary, :infant, :junior, :special
      if pupils < 100
        servers = 2
      elsif pupils < 300
        servers = 3
      else
        servers = 3 + (pupils / 300).floor
      end
    when :secondary, :middle, :mixed_primary_and_secondary
      power = 1000.0
      if pupils < 400
        servers = 4
      elsif pupils < 1000
        servers = 8
      else
        servers = 8 + ((pupils - 1000)/ 250).floor
      end
    else
      raise EnergySparksUnexpectedStateException.new("Unknown type of school #{school_type} in typical servers request") if !school_type.nil?
      raise EnergySparksUnexpectedStateException.new('Nil type of school in typical servers request') if school_type.nil?
    end
    [servers, power]
  end

  def self.recommended_baseload_for_floor_area(floor_area, school_type)
    school_type = school_type.to_sym if school_type.instance_of? String
    case school_type
    when :primary, :infant, :junior, :special
      if floor_area < 1000
        1.5
      elsif floor_area < 1600
        2.5
      else
        2.5 * (floor_area / 1600)
      end
    when :secondary, :middle, :mixed_primary_and_secondary
      if floor_area < 1000
        10
      else
        10 + 10 * (floor_area - 1000) / 1000
      end
    else
      raise EnergySparksUnexpectedStateException.new("Unknown type of school #{school_type} in baseload floor area request") if !school_type.nil?
      raise EnergySparksUnexpectedStateException.new('Nil type of school in baseload floor area request') if school_type.nil?
    end
  end
end
