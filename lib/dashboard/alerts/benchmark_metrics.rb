# benchmark metrics
#
module BenchmarkMetrics
  ELECTRICITY_PRICE = 0.12
  SOLAR_EXPORT_PRICE = 0.05
  GAS_PRICE = 0.03
  OIL_PRICE = 0.05
  PERCENT_ELECTRICITY_OUT_OF_HOURS_BENCHMARK = 0.3
  PERCENT_GAS_OUT_OF_HOURS_BENCHMARK = 0.3
  BENCHMARK_ELECTRICITY_USAGE_PER_PUPIL = 50_000.0 / 200.0
  BENCHMARK_ELECTRICITY_USAGE_PER_M2 = 50_000.0 / 1_200.0
  BENCHMARK_GAS_USAGE_PER_PUPIL = 115_000.0 / 200.0
  BENCHMARK_GAS_USAGE_PER_M2 = 115_000.0 / 1_200.0
  EXEMPLAR_GAS_USAGE_PER_M2 = 80.0
  EXEMPLAR_ELECTRICITY_USAGE_PER_PUPIL = 175

  def self.benchmark_annual_electricity_usage_kwh(school_type, pupils = 1)
    school_type = school_type.to_sym if school_type.instance_of? String
    check_school_type(school_type, 'benchmark electricity usage per pupil')

    case school_type
    when :primary, :infant, :junior, :special, :middle
      300.0 * pupils
    when :secondary
      400.0 * pupils
    end
  end

  def self.exemplar_annual_electricity_usage_kwh(school_type, pupils = 1)
    school_type = school_type.to_sym if school_type.instance_of? String
    check_school_type(school_type, 'benchmark electricity usage per pupil')

    case school_type
    when :primary, :infant, :junior, :special, :middle
      200.0 * pupils
    when :secondary
      300.0 * pupils
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
    when :secondary, :middle
      if pupils < 400
        10
      else
        10 + 10 * (pupils - 400) / 400
      end
    end
  end

  private_class_method def self.check_school_type(school_type, type = 'baseload benckmark')
    raise EnergySparksUnexpectedStateException.new("Nil type of school in #{type} request") if school_type.nil?
    if !%i[primary infant junior special middle secondary].include?(school_type)
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
    when :secondary, :middle
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
    when :secondary, :middle
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
