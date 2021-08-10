class TargetsProgress
  attr_reader :fuel_type

  def initialize(fuel_type:, months:, monthly_targets_kwh:, monthly_usage_kwh:, monthly_performance:, cumulative_targets_kwh:, cumulative_usage_kwh:, cumulative_performance:, partial_months:)
    @fuel_type = fuel_type
    @months = months
    @monthly_targets_kwh = monthly_targets_kwh
    @monthly_usage_kwh = monthly_usage_kwh
    @monthly_performance = monthly_performance
    @cumulative_targets_kwh = cumulative_targets_kwh
    @cumulative_usage_kwh = cumulative_usage_kwh
    @cumulative_performance = cumulative_performance
    @partial_months = partial_months
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

  def cumulative_targets_kwh
    to_keyed_collection(months, @cumulative_targets_kwh)
  end

  def cumulative_usage_kwh
    to_keyed_collection(months, @cumulative_usage_kwh)
  end

  def cumulative_performance
    to_keyed_collection(months, @cumulative_performance)
  end

  def current_cumulative_performance
    @cumulative_performance.compact.last
  end

  def partial_months
    @partial_months
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
