# aggregator - aggregates energy data in a form which can be used for generating charts
#
#     x_axis:   primarily date based: bucketing by year, month, week, day, 1/2 hour, none (implies intraday 1/2 hour but not bucketed)
#     series:   stacked representation on Y axis: [school day in/out of hours, weekend holiday] || [gas, electric, storage, PV] || hotwater [useful/non-useful]
#     y_axis:   [kwh data from meters || derived CUSUM data || baseload || hot water type] potentially converted to another proportional metric e.g. £/pupil
#     y2_axis:  temperature or degree day data - averaged or calculated, not aggregated
#
class Aggregator
  include Logging

  attr_reader :bucketed_data, :total_of_unit, :series_sums, :x_axis, :y2_axis
  attr_reader :x_axis_bucket_date_ranges, :data_labels

  def initialize(meter_collection, chart_config)
    @meter_collection = meter_collection
    @chart_config = chart_config
    @data_labels = nil
  end

  def title_summary
    if @chart_config[:yaxis_units] == :kw || @chart_config[:inject] == :benchmark
      ''
    else
      y_axis_label(@total_of_unit)
    end
  end

  def y_axis_label(value)
    YAxisScaling.unit_description(@chart_config[:yaxis_units], @chart_config[:yaxis_scaling], value)
  end

  def initialise_schools_date_range
    schools = @chart_config.key?(:schools) ? load_schools(@chart_config[:schools]) : [ @meter_collection ]

    determine_multi_school_chart_date_range(schools, @chart_config)

    [@chart_config, schools]
  end

  def aggregate
    bucketed_period_data = nil

    _chart_config, schools = initialise_schools_date_range

    periods = time_periods

    sort_by = @chart_config.key?(:sort_by) ? @chart_config[:sort_by] : nil

    bucketed_period_data = run_charts_for_multiple_schools_and_time_periods(schools, periods, sort_by)

    if bucketed_period_data.length > 1 || periods.length > 1
      @bucketed_data, @bucketed_data_count = merge_multiple_charts(bucketed_period_data, schools)
    else
      @bucketed_data, @bucketed_data_count = bucketed_period_data[0]
    end

    group_by = @chart_config.key?(:group_by) ? @chart_config[:group_by] : nil

    group_chart(group_by) unless group_by.nil? 

    inject_benchmarks if @chart_config[:inject] == :benchmark

    remove_filtered_series if @chart_config.key?(:filter) && @chart_config[:series_breakdown] != :none

    create_y2_axis_data if @chart_config.key?(:y2_axis)

    reorganise_buckets if @chart_config[:chart1_type] == :scatter

    remove_zero_data if @chart_config[:chart1_type] == :scatter

    scale_y_axis_to_kw if @chart_config[:yaxis_units] == :kw

    reverse_series_name_order(@chart_config[:series_name_order]) if @chart_config.key?(:series_name_order) && @chart_config[:series_name_order] == :reverse

    reverse_x_axis if @chart_config.key?(:reverse_xaxis) && @chart_config[:reverse_xaxis] == true

    aggregate_by_series

    @chart_config[:y_axis_label] = y_axis_label(nil)
  end

  private

  #=================regrouping of chart data ======================================
  # converts a flat structure e.g. :
  #     "electricity:Castle Primary School"=>[5.544020340000004, 2.9061917400000006, 0.45056400000000013], 
  #     "gas:Castle Primary School"=>[1.555860000000001, 1.4714710106863198, 1.405058200146572]
  # into a hierarchical 'grouped' structure e.g.
  #   {"electricity"=>
  #     {"Castle Primary School"=>[5.544020340000004, 2.9061917400000006, 0.45056400000000013],
  #      "Paulton Junior School"=>[2.47196688, 3.4770422399999985, 2.320555619999999],
  # to better represent the grouping of clustered/grouped/stacked charts to downstream graphing/display

  def group_chart(group_by)
    @bucketed_data = regroup_bucketed_data(@bucketed_data, group_by)
    @bucketed_data_count = regroup_bucketed_data(@bucketed_data_count, group_by)
    @x_axis = regroup_xaxis(bucketed_data, @x_axis)
  end

  # rubocop:enable MethodComplexity 
  def regroup_bucketed_data(bucketed_data, group_by)
    logger.info "Reorganising grouping of chart bucketed data, grouping by #{group_by.inspect}"
    logger.info "Original bucketed data: #{bucketed_data.inspect}"

    grouped_bucketed_data = Hash.new{ |h, k| h[k] = Hash.new(&h.default_proc)}
    final_hash = {}

    bucketed_data.each do |main_key, data|
      sub_keys = main_key.split(':')
      case  sub_keys.length
      when 1
        grouped_bucketed_data[sub_keys[0]] = data
      when 2
        grouped_bucketed_data[sub_keys[0]][sub_keys[1]] = data
      when 3
        grouped_bucketed_data[sub_keys[0]][sub_keys[1]][sub_keys[2]] = data
      else
        throw EnergySparksBadChartSpecification.new("Bad grouping specification too much grouping depth #{sub_keys.length}")
      end
    end
    logger.info  "Reorganised bucketed data: #{grouped_bucketed_data.inspect}"
    grouped_bucketed_data
  end

  def regroup_xaxis(bucketed_data, x_axis)
    puts "Old xaxis: #{x_axis.inspect}"
    puts "Old buckets: #{bucketed_data.inspect}"
    new_x_axis = {}
    puts bucketed_data.class.name
    bucketed_data.each do |series_name, school_data| # electricity|gas =>  school => [array of kwh 1 per year]
      puts "L", series_name.class.name, school_data.class.name
      school_data.each do |school_name, _kwhs|
        new_x_axis[school_name] = x_axis
      end
    end
    puts "New xaxis: #{new_x_axis.inspect}"
  end
  # rubocop:disable MethodComplexity
  #=============================================================================
  def load_schools(school_list)
    # school = $SCHOOL_FACTORY.load_school(school_name)
    schools = []
    school_list.each do |school_attribute|
      identifier_type, identifier = school_attribute.first
      
      bm = Benchmark.measure {
        school = $SCHOOL_FACTORY.load_or_use_cached_meter_collection(identifier_type, identifier, :analytics_db)
        schools.push(school)
      }
      logger.info "Loaded School: #{identifier_type} #{identifier} in #{bm.to_s}"
    end
    schools
  end

  def determine_multi_school_chart_date_range(schools, chart_config)
    logger.info '-' * 120
    logger.info "Determining maximum chart range for #{schools.length} schools:"
    min_date = nil
    max_date = nil

    schools.each do |school|
      series_manager = SeriesDataManager.new(school, chart_config)
      logger.info "    #{school.name} from #{series_manager.first_meter_date} to  #{series_manager.last_meter_date}"
      min_date = series_manager.first_meter_date if min_date.nil? || series_manager.first_meter_date > min_date
      max_date = series_manager.last_meter_date  if max_date.nil? || series_manager.last_meter_date  < max_date
    end

    chart_config[:min_combined_school_date] = min_date
    chart_config[:max_combined_school_date] = max_date

    description = schools.length > 1 ? 'Combined school charts' : 'School chart'
    logger.info description + " date range #{min_date} to #{max_date}"
    logger.info '-' * 120
  end

  def run_charts_for_multiple_schools_and_time_periods(schools, periods, sort_by = nil)
    saved_meter_collection = @meter_collection
    aggregations = []
    # iterate through the time periods aggregating
    schools.each do |school|
      @meter_collection = school
      periods.reverse.each do |period| # do in reverse so final iteration represents the x-axis dates
        aggregation = run_one_aggregation(@chart_config, period)
        aggregations.push(
          {
            school:       school,
            period:       period,
            aggregation:  aggregation
          }
        ) unless aggregation.nil?
      end
    end

    aggregations = sort_aggregations(aggregations, sort_by) unless sort_by.nil?

    bucketed_period_data = aggregations.map{ |aggregation_description| aggregation_description[:aggregation] }

    @meter_collection = saved_meter_collection

    bucketed_period_data
  end

  # sorting config example:      sort_by:          [ { school: :desc }, { time: :asc } ]
  # messy, could be simplified?
  def sort_aggregations(aggregations, sort_by)
    logger.info "About to sort #{aggregations.length} aggregations by #{sort_by}"
    aggregations.sort! { |x, y| 
      if sort_by.length == 1
        if sort_by[0].key?(:school)
          school_compare(x, y, sort_by[0][:school])
        elsif sort_by[0].key?(:time)
          period_compare(x, y, sort_by[0][:period])
        else
          throw EnergySparksBadChartSpecification.new("Bad sort specification #{sort_by}")
        end
      else
        if sort_by[0].key?(:school)
          if x[:school].name == y[:school].name
            period_compare(x, y, sort_by[1][:period])
          else
            school_compare(x, y, sort_by[0][:school])
          end
        elsif sort_by[0].key?(:time)
          if x[:period].start_date == y[:period].start_date
            school_compare(x, y, sort_by[1][:school])
          else
            period_compare(x, y, sort_by[0][:period])
          end
        else
          throw EnergySparksBadChartSpecification.new("Bad sort specification 2 #{sort_by}")
        end
      end 
    }
    aggregations
  end

  def period_compare(p1, p2, direction_definition)
    direction = direction_definition == :asc ? 1 : -1
    direction * ((p1[:period].nil? ? 0 : p1[:period].start_date) <=> (p2[:period].nil? ? 0 : p2[:period].start_date))
  end

  def school_compare(s1, s2, direction_definition)
    direction = direction_definition == :asc ? 1 : -1
    direction * (s1[:school].name <=> s2[:school].name)
  end

  def run_one_aggregation(chart_config, period)
    aggregation = nil
    chartconfig_copy = chart_config.clone
    chartconfig_copy[:timescale] = period
    begin
      aggregation = aggregate_period(chartconfig_copy)
    rescue EnergySparksMissingPeriodForSpecifiedPeriodChart => e
      logger.error e
      logger.error 'Warning: chart specification calls for more fixed date periods than available in AMR data'
    rescue StandardError => e
      logger.error e
    end
    aggregation
  end

  def aggregate_multiple_charts(periods)
    bucketed_period_data = []

    # iterate through the time periods aggregating
    periods.reverse.each do |period| # do in reverse so final iteration represents the x-axis dates
      chartconfig_copy = @chart_config.clone
      chartconfig_copy[:timescale] = period
      begin
        bucketed_period_data.push(aggregate_period(chartconfig_copy))
      rescue EnergySparksMissingPeriodForSpecifiedPeriodChart => e
        logger.error e
        logger.error 'Warning: chart specification calls for more fixed date periods than available in AMR data'
      rescue StandardError => e
        logger.error e
      end
    end
    bucketed_period_data
  end

  def merge_multiple_charts(bucketed_period_data, schools)
    @bucketed_data = {}
    @bucketed_data_count = {}
    time_count, school_count = count_time_periods_and_school_names(bucketed_period_data)
    bucketed_period_data.each do |period_data|
      bucketed_data, bucketed_data_count, time_description, school_name, x_axis, x_axis_date_ranges = period_data
      time_description  = time_count <= 1 ? '' : (':' + time_description)
      school_name = (schools.nil? || schools.length <= 1) ? '' : (':' + school_name)
      school_name = '' if school_count <= 1
      bucketed_data.each do |series_name, x_data|
        new_series_name = series_name.to_s + time_description + school_name
        @bucketed_data[new_series_name] = x_data
      end
      bucketed_data_count.each do |series_name, x_data|
        new_series_name = series_name.to_s + time_description + school_name
        @bucketed_data_count[new_series_name] = x_data
      end
    end
    [@bucketed_data, @bucketed_data_count]
  end

  def count_time_periods_and_school_names(bucketed_period_data)
    time_period_descriptions = {}
    school_names = {}
    bucketed_period_data.each do |period_data|
      bucketed_data, bucketed_data_count, time_description, school_name = period_data
      time_period_descriptions[time_description] = true
      school_names[school_name] = true
    end
    [time_period_descriptions.keys.length, school_names.keys.length]
  end

  def reverse_series_name_order(format)
    if format.is_a?(Symbol) && format == :reverse
      @bucketed_data = @bucketed_data.to_a.reverse.to_h
      @bucketed_data_count = @bucketed_data.to_a.reverse.to_h
    elsif format.is_a?(Array) # TODO(PH,22Jul2018): written but not tested, by be useful in future
      data = {}
      count = {}
      format.each do |series_name|
        data[series_name] = @bucketed_data[series_name]
        count[series_name] = @bucketed_data_count[series_name]
      end
      @bucketed_data = data
      @bucketed_data_count = count
    end
  end

  def reverse_x_axis
    @x_axis = @x_axis.reverse
    @x_axis_bucket_date_ranges = @x_axis_bucket_date_ranges.reverse

    @bucketed_data.each_key do |series_name|
      @bucketed_data[series_name] = @bucketed_data[series_name].reverse
      @bucketed_data_count[series_name] = @bucketed_data_count[series_name].reverse
    end

    unless @y2_axis.nil?
      @y2_axis.each_key do |series_name|
        @y2_axis[series_name] = @y2_axis[series_name].reverse
      end
    end
  end

  # charts can be specified as working over a single time period
  # or for comparison's between dates over muliple time periods
  # convert single hashes into an array with a single value
  def time_periods
    periods = []
    if !@chart_config.key?(:timescale)
      # if no time periods specified signal to series_data_manager
      # to use as much of the available data as possible i.e.
      # an unlimited timeperiod, seems to cause problems on Macs if not?
      periods.push(nil)
    elsif @chart_config[:timescale].is_a?(Array)
      periods = @chart_config[:timescale]
    else
      periods.push(@chart_config[:timescale])
    end
    periods
  end

  def aggregate_period(chart_config)
    @series_manager = SeriesDataManager.new(@meter_collection, chart_config)
    @series_names = @series_manager.series_bucket_names
    logger.info "Aggregating these series #{@series_names}"
    logger.info "aggregate_period Between #{@series_manager.first_chart_date} and #{@series_manager.last_chart_date}"

    if @series_manager.periods.empty?
      raise "Error: not enough data available to create requested chart"
    end
    @xbucketor = XBucketBase.create_bucketor(chart_config[:x_axis], @series_manager.periods)
    @xbucketor.create_x_axis
    @x_axis = @xbucketor.x_axis
    @x_axis_bucket_date_ranges = @xbucketor.x_axis_bucket_date_ranges
    logger.debug "Breaking down into #{@xbucketor.x_axis.length} X axis (date/time range) buckets"
    logger.debug "x_axis between #{@xbucketor.data_start_date} and #{@xbucketor.data_end_date} "
    bucketed_data, bucketed_data_count = create_empty_bucket_series

    # loop through date groups on the x-axis; calculate aggregate data for each series in date range

    if chart_config[:x_axis] == :intraday
      start_date = @series_manager.periods[0].start_date
      end_date = @series_manager.periods[0].end_date
      aggregate_by_halfhour(start_date, end_date, bucketed_data, bucketed_data_count)
    elsif chart_config[:x_axis] == :datetime
      start_date = @series_manager.periods[0].start_date
      end_date = @series_manager.periods[0].end_date
      aggregate_by_datetime(start_date, end_date, bucketed_data, bucketed_data_count)
    else
      aggregate_by_day(bucketed_data, bucketed_data_count)
    end

    [bucketed_data, bucketed_data_count, @xbucketor.compact_date_range_description, @meter_collection.name, @x_axis, @x_axis_bucket_date_ranges]
  end

private

  # aggregate by whole date range, the 'series_manager' deals with any spliting within a day
  # e.g. 'school day in hours' v. 'school day out of hours'
  # returns a hash of this breakdown to the kWh values
  def aggregate_by_day(bucketed_data, bucketed_data_count)
    count = 0
    if @chart_config.key?(:filter) && @chart_config[:filter].key?(:daytype)
      # this is slower, as it needs to loop through a day at a time
      # TODO(PH,17Jun2018) push down and optimise in series_data_manager
      @xbucketor.x_axis_bucket_date_ranges.each do |date_range|
        x_index = @xbucketor.index(date_range[0], nil)
        (date_range[0]..date_range[1]).each do |date|
          next unless match_filter_by_day(date)
          multi_day_breakdown = @series_manager.get_data([:daterange, [date, date]])
          multi_day_breakdown.each do |key, value|
            add_to_bucket(bucketed_data, bucketed_data_count, key, x_index, value)
            count += 1
          end
        end
      end
    else
      @xbucketor.x_axis_bucket_date_ranges.each do |date_range|
        x_index = @xbucketor.index(date_range[0], nil)
        multi_day_breakdown = @series_manager.get_data([:daterange, date_range])
        multi_day_breakdown.each do |key, value|
          add_to_bucket(bucketed_data, bucketed_data_count, key, x_index, value)
          count += 1
        end
      end
    end
    logger.info "aggregate_by_day:  aggregated #{count} items"
  end

  def match_filter_by_day(date)
    return true unless @chart_config.key?(:filter)
    match_daytype = true
    match_daytype = match_occupied_type_filter_by_day(date) if @chart_config[:filter].key?(:daytype)
    match_heating = true
    match_heating = match_filter_by_heatingdayday(date) if @chart_config[:filter].key?(:heating)
    match_daytype && match_heating
  end

  def match_filter_by_heatingdayday(date)
    @chart_config[:filter][:heating] == @series_manager.heating_model.heating_on?(date)
  end

  def match_occupied_type_filter_by_day(date)
    filter = @chart_config[:filter][:daytype]
    holidays = @meter_collection.holidays
    case filter
    when :occupied
      !(DateTimeHelper.weekend?(date) || holidays.holiday?(date))
    when :holidays
      holidays.holiday?(date)
    when :weekends
      DateTimeHelper.weekend?(date)
    else
      true
    end
  end

  def aggregate_by_halfhour(start_date, end_date, bucketed_data, bucketed_data_count)
    (start_date..end_date).each do |date|
      next if !match_filter_by_day(date)
      (0..47).each do |halfhour_index|
        x_index = @xbucketor.index(nil, halfhour_index)
        multi_day_breakdown = @series_manager.get_data([:halfhour, date, halfhour_index])
        multi_day_breakdown.each do |key, value|
          add_to_bucket(bucketed_data, bucketed_data_count, key, x_index, value)
        end
      end
    end
  end

  def aggregate_by_datetime(start_date, end_date, bucketed_data, bucketed_data_count)
    (start_date..end_date).each do |date|
      next if !match_filter_by_day(date)
      (0..47).each do |halfhour_index|
        x_index = @xbucketor.index(date, halfhour_index)
        multi_day_breakdown = @series_manager.get_data([:datetime, date, halfhour_index])
        multi_day_breakdown.each do |key, value|
          add_to_bucket(bucketed_data, bucketed_data_count, key, x_index, value)
        end
      end
    end
  end

  # this is a bit of a fudge, the data from a thermostatic scatter aggregation comes out
  # in the wrong order by default for most graphing packages, so the columns of data need
  # reorganising
  def reorganise_buckets
    dd_or_temp_key = @bucketed_data.key?(SeriesNames::DEGREEDAYS) ? SeriesNames::DEGREEDAYS : SeriesNames::TEMPERATURE
    # replace dates on x axis with degree days, but retain them for future point labelling
    x_axis = @x_axis
    @x_axis = @bucketed_data[dd_or_temp_key]
    @x_axis_bucket_date_ranges = @xbucketor.x_axis_bucket_date_ranges # may not work? PH 7Oct2018
    @bucketed_data.delete(dd_or_temp_key)

    # insert dates back in as 'silent' y2_axis
    @data_labels = x_axis
  end

  # remove zero data - issue with filtered scatter charts, and the difficulty or representing nan (NaN) in Excel charts
  # the issue is the xbuckector doesn't know in advance the data is to be filtered based on the data
  # but the charting products can't distinguish between empty data and zero data
  def remove_zero_data
    count = 0  
    indices_of_data_to_be_removed = []
    (0..@x_axis.length - 1).each do |index|
      indices_of_data_to_be_removed.push(index) if @x_axis[index] == 0
    end

    indices_of_data_to_be_removed.reverse.each do |index| # reverse order to works on self
      @x_axis.delete_at(index)
      @bucketed_data.each_key do |series_name|
        if @bucketed_data.key?(series_name) && !@bucketed_data[series_name].nil?
          @bucketed_data[series_name].delete_at(index)
          @bucketed_data_count[series_name].delete_at(index)
        else
          logger.error "Error: expecting non nil series name #{series_name}"
        end
      end
    end
    logger.info "Removing zero data: removed #{indices_of_data_to_be_removed.length} items"
  end

  # pattern matches on series_names, removing any from list which don't match
  def remove_filtered_series
    keep_key_list = []
    ap(@bucketed_data, limit: 20, color: { float: :red }) if ENV['AWESOMEPRINT'] == 'on'
    logger.info "Filtering start #{@bucketed_data.keys}"
    logger.debug @chart_config[:filter].inspect if @chart_config.key?(:filter)
    if @chart_config[:series_breakdown] == :submeter
      if @chart_config[:filter].key?(:submeter)
        keep_key_list += pattern_match_list_with_list(@bucketed_data.keys, @chart_config[:filter][:submeter])
      else
        keep_key_list += @bucketed_data.keys # TODO(PH,2Jul2018) may not be generic enough?
      end
    end
    keep_key_list += pattern_match_list_with_list(@bucketed_data.keys, @chart_config[:filter][:meter]) if @chart_config[:filter].key?(:meter)
    if @chart_config.key?(:filter) && @chart_config[:filter].key?(:heating)
      filter = @chart_config[:filter][:heating] ? [SeriesNames::HEATINGDAY, SeriesNames::HEATINGDAYMODEL] : [SeriesNames::NONHEATINGDAY, SeriesNames::NONHEATINGDAYMODEL]
      keep_key_list += pattern_match_list_with_list(@bucketed_data.keys, filter)
    end
    if @chart_config.key?(:filter) && @chart_config[:filter].key?(:fuel)
      filtered_fuel = @chart_config[:filter][:fuel]
      keep_key_list += pattern_match_list_with_list(@bucketed_data.keys, [filtered_fuel])
    end
    if @chart_config.key?(:filter) && @chart_config[:filter].key?(:daytype)
      filtered_daytype = @chart_config[:filter][:daytype]
      keep_key_list += pattern_match_list_with_list(@bucketed_data.keys, [filtered_daytype])
    end
    keep_key_list.push(SeriesNames::DEGREEDAYS) if @bucketed_data.key?(SeriesNames::DEGREEDAYS)
    keep_key_list.push(SeriesNames::TEMPERATURE) if @bucketed_data.key?(SeriesNames::TEMPERATURE)
    keep_key_list.push(SeriesNames::IRRADIANCE) if @bucketed_data.key?(SeriesNames::IRRADIANCE)
    keep_key_list.push(SeriesNames::GRIDCARBON) if @bucketed_data.key?(SeriesNames::GRIDCARBON)

    remove_list = []
    @bucketed_data.each_key do |series_name|
      remove_list.push(series_name) unless keep_key_list.include?(series_name)
    end

    remove_list.each do |remove_series_name|
      @bucketed_data.delete(remove_series_name)
    end
    logger.debug ap(@bucketed_data, limit: 20, color: { float: :red }) if ENV['AWESOMEPRINT'] == 'on'
    logger.debug "Filtered End #{@bucketed_data.keys}"
  end

  def pattern_match_list_with_list(list, pattern_list)
    filtered_list = []
    pattern_list.each do |pattern|
      pattern_matched_list = list.select{ |i| i == pattern } # TODO(PH,26Jun2018) decide whether to pattern match /Lighting/ =['Lighting', 'Security Lighting']
      filtered_list += pattern_matched_list unless pattern_matched_list.empty?
    end
    filtered_list
  end

  def create_y2_axis_data
    # move bucketed data to y2 axis if configured that way
    # does via pattern matching of names to support multiple
    # dated y2 axis series
    logger.debug "Moving #{@chart_config[:y2_axis]} onto Y2 axis"

    # rubocop:disable Style/ConditionalAssignment
    y2_axis_names = []
    key_name = SeriesNames.y2_axis_key(@chart_config[:y2_axis])
    y2_axis_names = @bucketed_data.keys.grep(/#{key_name}/)
    # rubocop:enable Style/ConditionalAssignment
    @y2_axis = {}
    y2_axis_names.each do |series_name|
      @y2_axis[series_name] = @bucketed_data[series_name]
      @bucketed_data.delete(series_name)
    end
  end

  # once the aggregation process is complete, add up the aggregated data per series
  # for additional series total information which can be added to the chart legend and title
  def aggregate_by_series
    @series_sums = {}
    @total_of_unit = 0.0
    @bucketed_data.each do |series_name, units|
      @series_sums[series_name] = all_values(units)
    end
    @total_of_unit += all_values(@bucketed_data)
  end

  def all_values(obj)
    float_data = []
    find_all_floats(float_data, obj)
    float_data.inject(:+)
  end

  # recursive search through hash/array for all float values
  def find_all_floats(float_data, obj) 
    if obj.is_a?(Hash)
      obj.each_value do |val|
        find_all_floats(float_data, val)
      end
    elsif obj.is_a?(Array)
      obj.each do |val|
        find_all_floats(float_data, val)
      end
    elsif obj.is_a?(Float)
      float_data.push(obj)
    else
      logger.info "Unexpected type #{val.class.name} to sum"
    end
  end

  def add_to_bucket(bucketed_data, bucketed_data_count, series_name, x_index, value)
    logger.debug "Unknown series name #{series_name} not in #{bucketed_data.keys}" if !bucketed_data.key?(series_name)
    bucketed_data[series_name][x_index] += value
    bucketed_data_count[series_name][x_index] += 1 # required to calculate kW
  end

  # kw to kwh scaling is slightly painful as you need to know how many buckets
  # the scaling factor code which is used in the initial seriesdatamanager bucketing
  # already multiplies the kWh by 2, to scale from 1/2 hour to 1 hour
  def scale_y_axis_to_kw
    @bucketed_data.each do |series_name, data|
      (0..data.length - 1).each do |index|
        date_range = @xbucketor.x_axis_bucket_date_ranges[index]
        days = date_range[1] - date_range[0] + 1.0
        if @chart_config[:x_axis] == :intraday || @chart_config[:x_axis] == :datetime
          # intraday kwh data gets bucketed into 48 x 1/2 hour buckets
          # kw = kwh in bucket / dates in bucket * 2 (kWh per 1/2 hour)
          count = @bucketed_data_count[series_name][index]
          # rubocop:disable Style/ConditionalAssignment
          if count > 0
            @bucketed_data[series_name][index] = 2 * @bucketed_data[series_name][index] / count
          else
            @bucketed_data[series_name][index] = 0
          end
          # rubocop:enable Style/ConditionalAssignment
        else
          hours = days * 24
          @bucketed_data[series_name][index] /= hours
        end
      end
    end
  end

  def inject_benchmarks
    logger.info 'Injecting national, regional and exemplar bencmark data'
    ap(@x_axis)
    ap(@bucketed_data)
puts @bucketed_data.inspect
    if (@bucketed_data.key?('electricity') && @bucketed_data['electricity'].is_a?(Array)) ||
       (@bucketed_data.key?('gas') && @bucketed_data['gas'].is_a?(Array))
      @x_axis.push('National Average')
      @bucketed_data['electricity'].push(benchmark_electricity_usage_in_units)
      @bucketed_data['gas'].push(benchmark_gas_usage_in_units)

      @x_axis.push('Regional Average')
      @bucketed_data['electricity'].push(benchmark_electricity_usage_in_units)
      @bucketed_data['gas'].push(benchmark_gas_usage_in_units * 0.9)

      @x_axis.push('Exemplar School')
      @bucketed_data['electricity'].push(exemplar_electricity_usage_in_units)
      @bucketed_data['gas'].push(exemplar_gas_usage_in_units * 0.9)
    else
      @x_axis.push('National Average')
      @bucketed_data['electricity']['National Average'] = benchmark_electricity_usage_in_units
      @bucketed_data['gas']['National Average'] = benchmark_gas_usage_in_units

      @x_axis.push('Regional Average')
      @bucketed_data['electricity']['Regional Average'] = benchmark_electricity_usage_in_units
      @bucketed_data['gas']['Regional Average'] = benchmark_gas_usage_in_units * 0.9

      @x_axis.push('Exemplar School')
      @bucketed_data['electricity']['Exemplar School'] = exemplar_electricity_usage_in_units
      @bucketed_data['gas']['Exemplar School'] = exemplar_gas_usage_in_units * 0.9
    end
  end

  def exemplar_electricity_usage_in_units
    e_exemplar_kwh = BenchmarkMetrics::EXEMPLAR_ELECTRICITY_USAGE_PER_PUPIL * @meter_collection.number_of_pupils
    y_scaling = YAxisScaling.new
    y_scaling.scale_from_kwh(e_exemplar_kwh, @chart_config[:yaxis_units], @chart_config[:yaxis_scaling], :electricity, @meter_collection)
  end

  def exemplar_gas_usage_in_units
    g_exemplar_kwh = BenchmarkMetrics::EXEMPLAR_GAS_USAGE_PER_M2 * @meter_collection.floor_area
    y_scaling = YAxisScaling.new
    y_scaling.scale_from_kwh(g_exemplar_kwh, @chart_config[:yaxis_units], @chart_config[:yaxis_scaling], :gas, @meter_collection)
  end

  def benchmark_electricity_usage_in_units
    e_benchmark_kwh = BenchmarkMetrics::BENCHMARK_ELECTRICITY_USAGE_PER_PUPIL * @meter_collection.number_of_pupils
    y_scaling = YAxisScaling.new
    y_scaling.scale_from_kwh(e_benchmark_kwh, @chart_config[:yaxis_units], @chart_config[:yaxis_scaling], :electricity, @meter_collection)
  end

  def benchmark_gas_usage_in_units
    g_benchmark_kwh = BenchmarkMetrics::BENCHMARK_GAS_USAGE_PER_M2 * @meter_collection.floor_area
    y_scaling = YAxisScaling.new
    y_scaling.scale_from_kwh(g_benchmark_kwh, @chart_config[:yaxis_units], @chart_config[:yaxis_scaling], :gas, @meter_collection)
  end

  def create_empty_bucket_series
    logger.debug "Creating empty data buckets #{@series_names} x #{@x_axis.length}"
    bucketed_data = {}
    bucketed_data_count = {}
    @series_names.each do |series_name|
      bucketed_data[series_name] = Array.new(@x_axis.length, 0.0)
      bucketed_data_count[series_name] = Array.new(@x_axis.length, 0)
    end
    [bucketed_data, bucketed_data_count]
  end
end
