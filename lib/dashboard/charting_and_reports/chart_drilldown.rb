# Chart Manager drilldown
# - given and existing chart, and drilldown, returns a drilldown chart
class ChartManager
  include Logging

  def drilldown(old_chart_name, chart_config_original, series_name, x_axis_range)
    chart_config = resolve_chart_inheritance(chart_config_original)

    chart_config[:parent_chart_xaxis_config] = chart_config[:timescale] # save for front end 'up/back' button text

    if chart_config[:series_breakdown] == :baseload ||
       chart_config[:series_breakdown] == :cusum ||
       chart_config[:series_breakdown] == :hotwater ||
       chart_config[:series_breakdown] == :heating ||
       chart_config[:chart1_type]      == :scatter
       # these special case may need reviewing if we decide to aggregate
       # these types of graphs by anything other than days
       # therefore create a single date datetime drilldown

       chart_config[:chart1_type] = :column
       chart_config[:series_breakdown] = :none
    else
      ap(chart_config, limit: 20, color: { float: :red }) if ENV['AWESOMEPRINT'] == 'on'

      chart_config.delete(:inject)

      unless series_name.nil?
        new_filter = drilldown_series_name(chart_config, series_name)
        chart_config = chart_config.merge(new_filter)
      end

      chart_config[:chart1_type] = :column if chart_config[:chart1_type] == :bar
    end

    unless x_axis_range.nil?
      new_timescale_x_axis = drilldown_daterange(chart_config, x_axis_range)
      chart_config = chart_config.merge(new_timescale_x_axis)
    end

    new_chart_name = (old_chart_name.to_s + '_drilldown').to_sym

    chart_config[:name] = drilldown_title(chart_config, series_name, x_axis_range)

    ap(chart_config, color: { float: :red }) if ENV['AWESOMEPRINT'] == 'on'

    reformat_dates(chart_config)

    [new_chart_name, chart_config]
  end

  private def drilldown_title(chart_config, series_name, x_axis_range)
    if chart_config.key?(:drilldown_name)
      index = chart_config[:drilldown_name].index(chart_config[:name])
      if !index.nil? && index < chart_config[:drilldown_name].length - 1
        chart_config[:drilldown_name][index + 1] 
      else
        chart_config[:drilldown_name][0]
      end
    else
      chart_config[:name] # + ((series_name.nil? && x_axis_range.nil?) ? ' no drilldown' : ' drilldown')
    end
  end

  private def reformat_dates(chart_config)
    if !chart_config[:x_axis].nil? && !%i[datetime dayofweek intraday nodatebuckets datetime].include?(chart_config[:x_axis])
      chart_config[:x_axis_reformat] = { date: '%d %b %Y' }
    elsif chart_config.key?(:x_axis_reformat)
      chart_config.delete(:x_axis_reformat)
    end
  end

  def parent_chart_timescale_description(chart_config)
    return nil if !chart_config.key?(:parent_chart_xaxis_config) # || chart_config[:parent_chart_xaxis_config].nil?
    # unlimited i.e. long term charts have no timescale, so set to :years
    timescale = chart_config[:parent_chart_xaxis_config].nil? ? :years : chart_config[:parent_chart_xaxis_config]
    ChartTimeScaleDescriptions.interpret_timescale_description(timescale)
  end

  def drilldown_series_name(chart_config, series_name)
    existing_filter = chart_config.key?(:filter) ? chart_config[:filter] : {}
    existing_filter[chart_config[:series_breakdown]] = series_name
    new_filter = { filter: existing_filter }
  end

  def drilldown_daterange(chart_config, x_axis_range)
    new_x_axis = x_axis_drilldown(chart_config[:x_axis])
    if new_x_axis.nil?
      raise EnergySparksBadChartSpecification.new("Illegal drilldown requested for #{chart_config[:name]}  call drilldown_available first")
    end

    date_range_config = {
      timescale: { daterange: x_axis_range[0]..x_axis_range[1] },
      x_axis: new_x_axis
    }
  end

  def drilldown_available?(chart_config_original)
    drilldown_available(chart_config_original)
  end

  def drilldown_available(chart_config_original)
    chart_config = resolve_chart_inheritance(chart_config_original)
    !x_axis_drilldown(chart_config[:x_axis]).nil? && chart_config_original[:series_breakdown] != :fuel
  end

  def x_axis_drilldown(existing_x_axis_config)
    case existing_x_axis_config
    when :year, :academicyear
      :week
    when :month, :week, :schoolweek, :workweek, :hotwater, :daterange
      :day
    when :day
      :datetime
    when :datetime, :dayofweek, :intraday, :nodatebuckets
      nil
    else
      raise EnergySparksBadChartSpecification.new("Unhandled x_axis drilldown config #{existing_x_axis_config}")
    end
  end
end
