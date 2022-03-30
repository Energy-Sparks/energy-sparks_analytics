class AggregatorResults
  def initialize(data)
    @data = data
  end

  def self.create(bucketed_data, bucketed_data_count, x_axis, x_axis_bucket_date_ranges, y2_axis)
    data_copy = {
      bucketed_data:              bucketed_data,
      bucketed_data_count:        bucketed_data_count,
      x_axis:                     x_axis,
      x_axis_bucket_date_ranges:  x_axis_bucket_date_ranges,
      y2_axis:                    y2_axis
    }
    AggregatorResults.new(data_copy)
  end

  def unpack
    @data.values
  end

  def bucketed_data;              @data[:bucketed_data]             end
  def bucketed_data_count;        @data[:bucketed_data_count]       end
  def x_axis;                     @data[:x_axis]                    end
  def x_axis_bucket_date_ranges;  @data[:x_axis_bucket_date_ranges] end
  def y2_axis;                    @data[:y2_axis]                   end

  def reverse_x_axis
    @data[:x_axis] = @data[:x_axis].reverse
    @data[:x_axis_bucket_date_ranges]  = @data[:x_axis_bucket_date_ranges] .reverse

    bucketed_data.each_key do |series_name|
      @data[:bucketed_data][series_name] = bucketed_data[series_name].reverse
      @data[:bucketed_data_count][series_name] = bucketed_data_count[series_name].reverse
    end

    unless y2_axis.nil?
      @data[:y2_axis].each_key do |series_name|
        @data[:y2_axis][series_name] = y2_axis[series_name].reverse
      end
    end
  end

  # performs scaling to 200, 1000 pupils or primary/secondary default sized floor areas
  def scale_x_data(bucketed_data)
    # exclude y2_axis values e.g. temperature, degree days
    x_data_keys = bucketed_data.select { |series_name, _data| !Series::ManagerBase.y2_series_types.values.include?(series_name) }
    scale_factor = YAxisScaling.new.scaling_factor(@chart_config[:yaxis_scaling], @school)
    x_data_keys.each_key do |data_series_name|
      bucketed_data[data_series_name].each_with_index do |value, index|
        bucketed_data[data_series_name][index] = value * scale_factor
      end
    end
  end
end
