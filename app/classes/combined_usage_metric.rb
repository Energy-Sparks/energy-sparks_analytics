# In EnergySparks we frequently display usage, cost and carbon
# emissions alongside each other. E.g. as adjacent columns in a table
#
# To avoid passing round multiple separate variables and/or having multiple
# methods on service classes which return the same values in different units,
# the CombinedUsageMetric class is intended to encapsulate provision of a set of
# related values.
#
# These are always separately calculated as there isn't necessarily a linear
# relationship. E.g. varying tariffs over time mean that the cost of consumption
# might not be a simple multiple of the kwh value.
class CombinedUsageMetric
  attr_reader :kwh, :£, :co2
  def initialize(kwh:, £:, co2:)
    @kwh = kwh
    @£ = £
    @co2 = co2
  end
end
