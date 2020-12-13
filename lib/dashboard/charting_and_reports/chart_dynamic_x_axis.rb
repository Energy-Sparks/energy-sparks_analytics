# allows a chart to have different date range groupings on the
# x axis depending on how much data is available
# e.g. x_axis:    { 28..Float::INFINITY => :week, 4..27 => :day, 0..3 =>  :datetime},
class ChartDynamicXAxis
  def initialize(meter_collection, chart_config)
    @meter_collection = meter_collection
    @chart_config     = chart_config
  end

  def self.standard_up_to_1_year_dynamic_x_axis
    { 28..Float::INFINITY => :week, 4..27 => :day, 0..3 =>  :datetime}
  end

  def self.is_dynamic?(chart_config)
    chart_config.key?(:x_axis) && chart_config[:x_axis].is_a?(Hash)
  end

  def redefined_chart_config
    clone = @chart_config.clone
    clone[:x_axis] = x_axis_grouping
    clone
  end

  private

  def x_axis_grouping
    days_data = aggregate_meter.amr_data.days
    @chart_config[:x_axis].select{ |date_range, _v| date_range === days_data }.values[0]
  end

  def aggregate_meter
    case @chart_config[:meter_definition]
    when :all; 
    when :allheat; @meter_collection.aggregated_heat_meters
    when :allelectricity; @meter_collection.aggregated_electricity_meters
    when :storage_heater_meter; @meter_collection.storage_heater_meter
    when :solar_pv_meter, :solar_pv; @meter_collection.aggregated_electricity_meters.sub_meters[:generation]
    else
      raise EnergySparksUnsupportedFunctionalityException, "Dynamic x axis grouping not supported on #{@chart_config[:meter_definition]} meter_definition chart config"
    end
  end
end