class AggregatorSingleSeries < AggregatorBase
  def aggregate_period
    configure_series_manager

    configure_xaxis_buckets

    bucketed_data, bucketed_data_count = create_empty_bucket_series

    aggregate

    post_process_aggregation

    [
      humanize_symbols(chart_config, bucketed_data),
      humanize_symbols(chart_config, bucketed_data_count),
      results.xbucketor.compact_date_range_description,
      @school.name,
      results.x_axis,
      results.x_axis_bucket_date_ranges
    ]
  end

  private

  def aggregate
    # loop through date groups on the x-axis; calculate aggregate data for each series in date range
    case chart_config[:x_axis]
    when :intraday
      start_date = @series_manager.periods[0].start_date
      end_date = @series_manager.periods[0].end_date
      aggregate_by_halfhour(start_date, end_date, bucketed_data, bucketed_data_count)
    when :datetime
      start_date = @series_manager.periods[0].start_date
      end_date = @series_manager.periods[0].end_date
      aggregate_by_datetime(start_date, end_date, bucketed_data, bucketed_data_count)
    else
      aggregate_by_day(bucketed_data, bucketed_data_count)
    end
  end

  def configure_series_manager
    @series_manager = Series::Multiple.new(@school, chart_config)
    @series_names = @series_manager.series_bucket_names
    logger.info "Aggregating these series #{@series_names}"
    logger.info "aggregate_period Between #{@series_manager.first_chart_date} and #{@series_manager.last_chart_date}"
    if @series_manager.periods.empty?
      raise "Error: not enough data available to create requested chart"
    end
  end

  def create_empty_bucket_series
    logger.debug "Creating empty data buckets #{@series_names} x #{@x_axis.length}"
    bucketed_data = {}
    bucketed_data_count = {}
    @series_names.each do |series_name|
      bucketed_data[series_name] = Array.new(@x_axis.length, nil)
      bucketed_data_count[series_name] = Array.new(@x_axis.length, 0)
    end
    [bucketed_data, bucketed_data_count]
  end

  def configure_xaxis_buckets
    @xbucketor = XBucketBase.create_bucketor(chart_config[:x_axis], @series_manager.periods)
    @xbucketor.create_x_axis
    @x_axis = @xbucketor.x_axis
    @x_axis_bucket_date_ranges = @xbucketor.x_axis_bucket_date_ranges
    logger.debug "Breaking down into #{@xbucketor.x_axis.length} X axis (date/time range) buckets"
    logger.debug "x_axis between #{@xbucketor.data_start_date} and #{@xbucketor.data_end_date} "
  end

  def post_process_aggregation
    puts "Skipping trendlines for the moment"
    # create_trend_lines(chart_config, results.bucketed_data, results.bucketed_data_count) if @series_manager.trendlines?
    results.scale_x_data(results.bucketed_data) unless config.config_none_or_nil?(:yaxis_scaling)
  end

  # aggregate by whole date range, the 'series_manager' deals with any spliting within a day
  # e.g. 'school day in hours' v. 'school day out of hours'
  # returns a hash of this breakdown to the kWh values
  def aggregate_by_day(bucketed_data, bucketed_data_count)
    count = 0
    if add_daycount_to_legend? || daytype_filter?
      # this is slower, as it needs to loop through a day at a time
      # TODO(PH,17Jun2018) push down and optimise in series_data_manager
      @xbucketor.x_axis_bucket_date_ranges.each do |date_range|
        x_index = @xbucketor.index(date_range[0], nil)
        (date_range[0]..date_range[1]).each do |date|
          next unless match_filter_by_day(date)
          multi_day_breakdown = @series_manager.get_data([:daterange, [date, date]])
          multi_day_breakdown.each do |key, value|
            add_to_bucket(key, x_index, value)
            count += 1
          end
        end
      end
    else
      @xbucketor.x_axis_bucket_date_ranges.each do |date_range|
        x_index = @xbucketor.index(date_range[0], nil)
        multi_day_breakdown = @series_manager.get_data([:daterange, date_range])
        unless multi_day_breakdown.nil? # added to support future targeted data past end of real meter date
        multi_day_breakdown.each do |key, value|
          add_to_bucket(key, x_index, value)
          count += 1
        end
      end
    end
    end
    logger.info "aggregate_by_day:  aggregated #{count} items"
  end

  def humanize_symbols(chart_config, hash)
    if chart_config[:series_breakdown] == :daytype
      hash.transform_keys{ |k| OpenCloseTime.humanize_symbol(k) }
    else
      hash
    end
  end

  def aggregate_by_halfhour(start_date, end_date, bucketed_data, bucketed_data_count)
    # Change Line Below 22Mar2019
    if bucketed_data.length == 1 && bucketed_data.keys[0] == Series::NoBreakdown::NONE
      aggregate_by_halfhour_simple_fast(start_date, end_date)
    else
      (start_date..end_date).each do |date|
        next if !match_filter_by_day(date)
        (0..47).each do |halfhour_index|
          x_index = @xbucketor.index(nil, halfhour_index)
          multi_day_breakdown = @series_manager.get_data([:halfhour, date, halfhour_index])
          multi_day_breakdown.each do |key, value|
            add_to_bucket(key, x_index, value)
          end
        end
      end
    end
  end

  def aggregate_by_halfhour_simple_fast(start_date, end_date)
    total = Array.new(48, 0)
    count = 0
    (start_date..end_date).each do |date|
      next unless match_filter_by_day(date)
      data = @series_manager.get_one_days_data_x48(date, @series_manager.kwh_cost_or_co2)
      total = AMRData.fast_add_x48_x_x48(total, data)
      count += 1
    end
    bucketed_data[Series::NoBreakdown::NONE] = total
    bucketed_data_count[Series::NoBreakdown::NONE] = Array.new(48, count)
  end

  def aggregate_by_datetime(start_date, end_date, bucketed_data, bucketed_data_count)
    (start_date..end_date).each do |date|
      next if !match_filter_by_day(date)
      (0..47).each do |halfhour_index|
        x_index = @xbucketor.index(date, halfhour_index)
        multi_day_breakdown = @series_manager.get_data([:datetime, date, halfhour_index])
        multi_day_breakdown.each do |key, value|
          add_to_bucket(key, x_index, value)
        end
      end
    end
  end

  def add_to_bucket(series_name, x_index, value)
    logger.warn "Unknown series name #{series_name} not in #{results.bucketed_data.keys}" if !results.bucketed_data.key?(series_name)
    logger.warn "nil value for #{series_name}" if value.nil?

    return if value.nil?

    if results.bucketed_data[series_name][x_index].nil?
      results.bucketed_data[series_name][x_index] = value
    else
      results.bucketed_data[series_name][x_index] += value
    end

    count = 1
    if add_daycount_to_legend?
      count = value != 0.0 ? 1 : 0
    end
    results.bucketed_data_count[series_name][x_index] += count # required to calculate kW
  end

  def add_daycount_to_legend?
    chart_config.key?(:add_day_count_to_legend) && chart_config[:add_day_count_to_legend]
  end
end