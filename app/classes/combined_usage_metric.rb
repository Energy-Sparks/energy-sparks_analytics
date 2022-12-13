#
# In EnergySparks we frequently display usage, cost and carbon
# emissions alongside each other. E.g. as adjacent columns in a table
#
# To avoid passing round multiple separate variables and/or having multiple
# methods on service classes which return the same values in different units,
# the CombinedUsageMetric class is intended to encapsulate provision of a set of
# three values.
#
# The identifier should be a symbol that can be used to clearly identify what
# has been calculated, and for use as a translation key.
#
class CombinedUsageMetric
  attr_reader :metric_id, :kwh, :£, :co2

  def initialize(metric_id:, kwh:, £:, co2:)
    @metric_id = metric_id
    @kwh = kwh
    @£ = £
    @co2 = co2
  end

  #TODO: finalise whether we are using this key structure
  def i18n_key
    'analytics.metrics' + metric_id.to_s
  end

end
