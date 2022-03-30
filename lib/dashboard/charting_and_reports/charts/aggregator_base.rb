class AggregatorBase
  include Logging
  attr_reader :results
  def initialize(school, chart_config, results)
    @school       = school
    @chart_config = chart_config
    @results      = results
  end
end
