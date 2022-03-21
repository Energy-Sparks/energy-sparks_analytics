class TargetsProgress
  attr_reader :fuel_type

  def initialize(fuel_type:, months:, monthly_targets_kwh:, monthly_usage_kwh:, monthly_performance:,
                                      cumulative_targets_kwh:, cumulative_usage_kwh:, cumulative_performance:,
                                      monthly_performance_versus_synthetic_last_year:, cumulative_performance_versus_synthetic_last_year:, partial_months:, percentage_synthetic:)
    @fuel_type = fuel_type
    @months = months
    @monthly_targets_kwh = monthly_targets_kwh
    @monthly_usage_kwh = monthly_usage_kwh
    @monthly_performance = monthly_performance
    @cumulative_targets_kwh = cumulative_targets_kwh
    @cumulative_usage_kwh = cumulative_usage_kwh
    @cumulative_performance = cumulative_performance
    @monthly_performance_versus_synthetic_last_year = monthly_performance_versus_synthetic_last_year
    @cumulative_performance_versus_synthetic_last_year = cumulative_performance_versus_synthetic_last_year
    @partial_months = partial_months
    @percentage_synthetic = percentage_synthetic
  end

  def monthly_targets_kwh
    to_keyed_collection(months, @monthly_targets_kwh)
  end

  def monthly_usage_kwh
    to_keyed_collection(months, @monthly_usage_kwh)
  end

  def monthly_performance
    to_keyed_collection(months, @monthly_performance)
  end

  def monthly_performance_versus_synthetic_last_year
    to_keyed_collection(months, @monthly_performance_versus_synthetic_last_year)
  end

  def cumulative_targets_kwh
    to_keyed_collection(months, @cumulative_targets_kwh)
  end

  def percentage_synthetic
    to_keyed_collection(months, @percentage_synthetic)
  end

  def cumulative_usage_kwh
    to_keyed_collection(months, @cumulative_usage_kwh)
  end

  def current_cumulative_usage_kwh
    @cumulative_usage_kwh.compact.last
  end

  def cumulative_performance
    to_keyed_collection(months, @cumulative_performance)
  end

  def current_cumulative_performance
    @cumulative_performance.compact.last
  end

  def cumulative_performance_versus_synthetic_last_year
    to_keyed_collection(months, @cumulative_performance_versus_synthetic_last_year)
  end

  def current_cumulative_performance_versus_synthetic_last_year
    @cumulative_performance_versus_synthetic_last_year.compact.last
  end

  def partial_months
    to_keyed_collection(months, @partial_months)
  end

  def months
    @months
  end

  private

  def to_keyed_collection(keys, data)
    ret = {}
    keys.each_with_index do |key, idx|
      ret[key] = data[idx]
    end
    ret
  end
end
