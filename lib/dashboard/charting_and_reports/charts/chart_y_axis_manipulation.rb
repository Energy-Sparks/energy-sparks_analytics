class ChartYAxisManipulation
  class CantChangeY1AxisException < StandardError; end
  class CantChangeY2AxisException < StandardError; end

  def initialize(school)
    @chart_manager = ChartManager.new(school)
  end

  def y1_axis_choices(inherited_chart_config)
    chart_config = @chart_manager.resolve_chart_inheritance(inherited_chart_config)

    if self.class.manipulatable_y1_axis_choices.include?(chart_config[:yaxis_units])
      return self.class.manipulatable_y1_axis_choices
    else
      nil
    end
  end

  def change_y1_axis_config(inherited_chart_config, new_axis_units)
    raise CantChangeY1AxisException, "Unable to change y1 axis to #{new_axis_units}" unless y1_axis_choices(inherited_chart_config).include?(new_axis_units)

    new_config = @chart_manager.resolve_chart_inheritance(inherited_chart_config)

    new_config.merge({yaxis_units: new_axis_units})
  end

  def y2_axis_choices(inherited_chart_config)
    chart_config = @chart_manager.resolve_chart_inheritance(inherited_chart_config)

    if self.class.manipulatable_y2_axis_choices.include?(chart_config[:y2_axis])
      return self.class.manipulatable_y2_axis_choices
    else
      nil
    end
  end

  def change_y2_axis_config(inherited_chart_config, new_axis_units)
    raise CantChangeY2AxisException, "Unable to change y2 axis to #{new_axis_units}" unless y2_axis_choices(inherited_chart_config).include?(new_axis_units)

    new_config = @chart_manager.resolve_chart_inheritance(inherited_chart_config)

    new_config.merge({y2_axis: new_axis_units})
  end

  
  def self.manipulatable_y1_axis_choices
    %i[kwh £ co2]
  end

  def self.manipulatable_y2_axis_choices
    %i[degreedays temperature]
  end
end
