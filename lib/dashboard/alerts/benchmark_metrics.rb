# benchmark metrics
#
module BenchmarkMetrics
  ELECTRICITY_PRICE = 0.12
  GAS_PRICE = 0.03
  OIL_PRICE = 0.05
  PERCENT_ELECTRICITY_OUT_OF_HOURS_BENCHMARK = 0.3
  PERCENT_GAS_OUT_OF_HOURS_BENCHMARK = 0.3
  BENCHMARK_ELECTRICITY_USAGE_PER_PUPIL = 50_000.0 / 200.0
  BENCHMARK_ELECTRICITY_USAGE_PER_M2 = 50_000.0 / 1_200.0
  BENCHMARK_GAS_USAGE_PER_PUPIL = 115_000.0 / 200.0
  BENCHMARK_GAS_USAGE_PER_M2 = 115_000.0 / 1_200.0

  def self.recommended_baseload_for_pupils(pupils, school_type)
    case school_type
    when :primary, :infant
      if pupils < 150
        1.5
      elsif pupils < 300
        2.5
      else
        2.5 * (pupils / 300)
      end
    when :secondary
      if pupils < 400
        10
      else
        10 + 10 * (pupils - 400) / 400
      end
    else
      raise 'Unknown type of school ' + school_type
    end
  end

  def self.recommended_baseload_for_floor_area(floor_area, school_type)
    case school_type
    when :primary, :infant
      if floor_area < 1000
        1.5
      elsif floor_area < 1600
        2.5
      else
        2.5 * (floor_area / 1600)
      end
    when :secondary
      if floor_area < 1000
        10
      else
        10 + 10 * (floor_area - 1000) / 1000
      end
    else
      raise 'Unknown type of school ' + school_type
    end
  end
end
