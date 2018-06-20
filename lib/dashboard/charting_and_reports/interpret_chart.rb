# base class for ChartColour and ChartAggregation
class InterpretChart
  attr_reader :chart_data
  def initialize(chart_data)
    @chart_data = chart_data
  end
end
