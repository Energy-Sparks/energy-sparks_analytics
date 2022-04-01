# aggregator - aggregates energy data in a form which can be used for generating charts
#
#     x_axis:   primarily date based: bucketing by year, month, week, day, 1/2 hour, none (implies intraday 1/2 hour but not bucketed)
#     series:   stacked representation on Y axis: [school day in/out of hours, weekend holiday] || [gas, electric, storage, PV] || hotwater [useful/non-useful]
#     y_axis:   [kwh data from meters || derived CUSUM data || baseload || hot water type] potentially converted to another proportional metric e.g. £/pupil
#     y2_axis:  temperature or degree day data - averaged or calculated, not aggregated
#
class Aggregator
  include Logging

  attr_reader :bucketed_data, :total_of_unit, :x_axis, :y2_axis
  attr_reader :x_axis_bucket_date_ranges, :data_labels, :x_axis_label
  attr_reader :first_meter_date, :last_meter_date, :multi_chart_x_axis_ranges

  def initialize(meter_collection, chart_config, show_reconciliation_values)
    @show_reconciliation_values = show_reconciliation_values
    @meter_collection = meter_collection
    @chart_config = chart_config
    @data_labels = nil
    @multi_chart_x_axis_ranges = []
  end

  def title_summary
    if @total_of_unit.is_a?(Float) && @total_of_unit.nan?
      'NaN total'
    else
      @show_reconciliation_values ? y_axis_label(@total_of_unit) : ''
    end
  end

  def y_axis_label(value)
    YAxisScaling.unit_description(@chart_config[:yaxis_units], @chart_config[:yaxis_scaling], value)
  end

  def valid
    !@bucketed_data.nil? && !@bucketed_data.empty?
  end

  def initialise_schools_date_range
    schools = [ @meter_collection ]

    if include_target?
      target_school = @meter_collection.target_school(@chart_config[:target][:calculation_type])

      if show_only_target_school?
        schools = [target_school]
      else
        schools << target_school
      end
    end

    if include_benchmark?
      @chart_config[:benchmark][:calculation_types].each do |calculation_type|
        benchmark_school = @meter_collection.benchmark_school(calculation_type)
        schools << benchmark_school
      end
    end

    determine_multi_school_chart_date_range(schools, @chart_config)

    [@chart_config, schools]
  end

  def aggregate
    bucketed_period_data = nil

    amsp = AggregatorMultiSchoolsPeriods.new(@meter_collection, @chart_config, nil)
    bucketed_period_data = amsp.calculate
    unpack_results2(amsp.final_results)
    periods = amsp.periods
    schools = amsp.schools
    @chart_config[:min_combined_school_date] = amsp.min_combined_school_date
    @chart_config[:max_combined_school_date] = amsp.max_combined_school_date

    if up_to_a_year_month_comparison?(@chart_config)
      @bucketed_data, @bucketed_data_count = merge_monthly_comparison_charts(bucketed_period_data)
    elsif bucketed_period_data.length > 1 || periods.length > 1
      @bucketed_data, @bucketed_data_count = merge_multiple_charts(bucketed_period_data, schools)
    else
      @bucketed_data, @bucketed_data_count = bucketed_period_data[0]
    end

    inject_benchmarks if @chart_config[:inject] == :benchmark && !@chart_config[:inject].nil?

    remove_filtered_series if chart_has_filter? && @chart_config[:series_breakdown] != :none

    create_y2_axis_data if y2_axis?

    reorganise_buckets if @chart_config[:chart1_type] == :scatter

    add_x_axis_label if @chart_config[:chart1_type] == :scatter

    # deprecated 28Feb2019
    # remove_zero_data if @chart_config[:chart1_type] == :scatter

    scale_y_axis_to_kw if @chart_config[:yaxis_units] == :kw

    nullify_trailing_zeros if nullify_trailing_zeros?

    accumulate_data if cumulative?

    reverse_series_name_order(@chart_config[:series_name_order]) if @chart_config.key?(:series_name_order) && @chart_config[:series_name_order] == :reverse

    reverse_x_axis if @chart_config.key?(:reverse_xaxis) && @chart_config[:reverse_xaxis] == true

    reformat_x_axis if @chart_config.key?(:x_axis_reformat) && !@chart_config[:x_axis_reformat].nil?

    mark_up_legend_with_day_count if add_daycount_to_legend?

    humanize_legend if humanize_legend?

    relabel_legend if relabel_legend?

    @chart_config[:y_axis_label] = y_axis_label(nil)

    swap_NaN_for_nil if true || Object.const_defined?('Rails')

    @chart_config[:name] = dynamic_chart_name(amsp.series_manager)
  end

  def subtitle
    return nil unless @chart_config.key?(:subtitle)
    if @chart_config[:subtitle] == :daterange && !@xbucketor.data_start_date.nil? && !@xbucketor.data_end_date.nil?
      @xbucketor.data_start_date.strftime('%e %b %Y') + ' to ' + @xbucketor.data_end_date.strftime('%e %b %Y')
    else
      'Internal error: expected subtitle request'
    end
  end

  def y2_axis?
    !config_none_or_nil?(:y2_axis, @chart_config)
  end

  private

  def dynamic_chart_name(series_manager)
    # make useful data available for binding
    school        = @meter_collection.school
    meter         = [series_manager.meter].flatten.first
    second_meter  = [series_manager.meter].flatten.last
    total_kwh = @bucketed_data.values.map{ |v| v.nil? ? 0.0 : v }.map(&:sum).sum.round(0) if @chart_config[:name].include?('total_kwh') rescue 0.0

    ERB.new(@chart_config[:name]).result(binding)
  end

  def chart_has_filter?
    !config_none_or_nil?(:filter, @chart_config)
  end

  def include_target?
    @chart_config.key?(:target) && !@chart_config[:target].nil?
  end

  def include_benchmark?
    @chart_config.key?(:benchmark) && !@chart_config[:benchmark].nil?
  end

  def show_only_target_school?
    @chart_config.key?(:target) && @chart_config[:target][:show_target_only] == true
  end

  def cumulative?
    @chart_config.key?(:cumulative) && @chart_config[:cumulative]
  end

  def nullify_trailing_zeros?
    @chart_config.key?(:nullify_trailing_zeros) && @chart_config[:nullify_trailing_zeros]
  end

  def ignore_single_series_failure?
    @chart_config.key?(:ignore_single_series_failure) && @chart_config[:ignore_single_series_failure]
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
          raise EnergySparksBadChartSpecification.new("Bad sort specification #{sort_by}")
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
          raise EnergySparksBadChartSpecification.new("Bad sort specification 2 #{sort_by}")
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

  def unpack_results2(res)
    @bucketed_data, @bucketed_data_count, @x_axis, @x_axis_bucket_date_ranges, @y2_axis, @series_manager, @series_names, @xbucketor = res.unpack2
  end

  def benchmark_school_config_override(school_name)
    return {} if @chart_config.dig(:benchmark, :calculation_types).nil? || @chart_config.dig(:benchmark, :config).nil?
    calc_types = @chart_config[:benchmark][:calculation_types].map(&:to_s)
    return {} unless calc_types.include?(school_name)

    @chart_config[:benchmark][:config]
  end

  def merge_multiple_charts(bucketed_period_data, schools)
    @bucketed_data = {}
    @bucketed_data_count = {}
    time_count, school_count = count_time_periods_and_school_names(bucketed_period_data)
    bucketed_period_data.each do |period_data|
      bucketed_data, bucketed_data_count, time_description, school_name, x_axis, x_axis_date_ranges = period_data
      time_description = time_count <= 1 ? '' : (':' + time_description)
      school_name = (schools.nil? || schools.length <= 1) ? '' : (':' + school_name)
      school_name = '' if school_count <= 1

      @multi_chart_x_axis_ranges.push(x_axis_date_ranges)

      bucketed_data.each do |series_name, x_data|
        new_series_name = series_name.to_s + time_description + school_name
        @bucketed_data[new_series_name] = x_data
      end
      bucketed_data_count.each do |series_name, count_data|
        new_series_name = series_name.to_s + time_description + school_name
        @bucketed_data_count[new_series_name] = count_data
      end
    end
    [@bucketed_data, @bucketed_data_count]
  end

  
  def up_to_a_year_month_comparison?(chart_config)
    timescales = chart_config[:timescale]
    return false if timescales.nil? || !timescales.is_a?(Array) || chart_config[:x_axis] != :month
    return false unless timescales.length > 1
    timescales.all? do |timescale|
      timescale.is_a?(Hash) && timescale.keys[0] == :up_to_a_year
    end
  end

  # one of merging of multiple chart series for year on year up_to_a_year
  # comparison reports - where there are mutliple years of data but not all
  # complete, and incomplete years have less data which needs to be aligned
  # to the correct month; TODO (PH, 5Apr2021) - consider redesign of whole bucketing system
  def merge_monthly_comparison_charts(bucketed_period_data)
    @bucketed_data = {}
    @bucketed_data_count = {}
    time_count, school_count = count_time_periods_and_school_names(bucketed_period_data)
    raise EnergySparksBadChartSpecification, 'More than one school not supported' if school_count > 1
    bucketed_period_data.reverse_each.with_index do |period_data, index|
      bucketed_data, bucketed_data_count, time_description, school_name, x_axis, x_axis_date_ranges = period_data

      @multi_chart_x_axis_ranges.push(x_axis_date_ranges)

      if index == 0
        @x_axis = x_axis.map{ |month_year| month_year[0..2]} # MMM YYYY to MMM
        @bucketed_data[      time_description] = bucketed_data.values[0]
        @bucketed_data_count[time_description] = bucketed_data_count.values[0]
      else
        time_description += "- partial year (from #{x_axis[0]})" if x_axis.length < @x_axis.length

        keys = x_axis.map{ |month_year| month_year[0..2]}

        new_x_data = @x_axis.map do |month|
          column = keys.find_index(month)
          column.nil? ? 0.0 : bucketed_data.values[0][column]
        end

        new_x_count_data = @x_axis.map do |month|
          column = keys.find_index(month)
          column.nil? ? 0.0 : bucketed_data_count.values[0][column]
        end

        @bucketed_data[time_description]       = new_x_data
        @bucketed_data_count[time_description] = new_x_count_data
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

  def nullify_trailing_zeros
    @bucketed_data.keys.each do |series_name|
      got_non_zero_value = false
      reorged_values = @bucketed_data[series_name].reverse.map do |val|
        got_non_zero_value = true if val != 0.0
        val == 0.0 && !got_non_zero_value ? nil : val
      end
      @bucketed_data[series_name] = reorged_values.reverse
    end
  end

  def accumulate_data
    @bucketed_data.keys.each do |series_name|
      running_total = 0.0
      @bucketed_data[series_name].map! do |val|
        val.nil? ? nil : (running_total += val)
      end
    end
  end

  def reformat_x_axis
    format = @chart_config[:x_axis_reformat]
    if format.is_a?(Hash) && format.key?(:date)
      @x_axis.map! { |date| date.is_a?(String) ? date : date.strftime(format[:date]) }
    else
      raise EnergySparksBadChartSpecification.new("Unexpected x axis reformat chart configuration #{format}")
    end
  end
=begin
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
=end
  def mark_up_legend_with_day_count
    @bucketed_data.keys.each do |series_name|
      days = @bucketed_data_count[series_name].sum
      new_series_name = series_name + " (#{days} days)"
      @bucketed_data[new_series_name] = @bucketed_data.delete(series_name)
      @bucketed_data_count[new_series_name] = @bucketed_data_count.delete(series_name)
    end
  end

  def humanize_legend
    @bucketed_data.keys.each do |series_name|
      new_series_name = series_name.to_s.humanize
      @bucketed_data[new_series_name] = @bucketed_data.delete(series_name)
      @bucketed_data_count[new_series_name] = @bucketed_data_count.delete(series_name)
    end
  end

  def relabel_legend
    @chart_config[:replace_series_label].each do |substitute_pair|
      @bucketed_data.keys.each do |series_name|
        original    = substitute_pair[0]
        replacement = substitute_pair[1]
        original = original.gsub('<school_name>', @meter_collection.name) if original.include?('<school_name>')
        new_series_name = series_name.gsub(original, replacement)
        @bucketed_data[new_series_name] = @bucketed_data.delete(series_name)
        @bucketed_data_count[new_series_name] = @bucketed_data_count.delete(series_name)
      end
    end
  end

  private

  # the analytics code treats missing and incorrectly calculated numbers as NaNs
  # unforunately the front end (Rails) prefers nil, so post process the entire
  # result set if running for rails to swap NaN for nil
  # analytics more performant in mainly using NaNs, as fewer tests required
  # e.g. total += value versus if total.nil? ? total = value : (value.nil? ? nil : total + value)
  def swap_NaN_for_nil
    return if @bucketed_data.nil?
    @bucketed_data.each do |series_name, result_data|
      unless result_data.is_a?(Symbol)
        @bucketed_data[series_name] = result_data.map do |x|
          x = x.to_f if is_a?(Integer)
          (x.nil? || x.finite?) ? x : nil
        end
      end
    end
  end

  def add_daycount_to_legend?
    @chart_config.key?(:add_day_count_to_legend) && @chart_config[:add_day_count_to_legend]
  end

  def relabel_legend?
    @chart_config.key?(:replace_series_label) && @chart_config[:replace_series_label]
  end

  def humanize_legend?
    @chart_config.key?(:humanize_legend) && @chart_config[:humanize_legend] && Object.const_defined?('Rails')
  end

  private def daytype_filter?
    has_filter?(:daytype) || has_filter?(:heating_daytype)
  end

  private def has_filter?(type)
    chart_has_filter? && @chart_config[:filter].key?(:type) && !@chart_config[:filter][type].nil?
  end

  private def config_none_or_nil?(config_key, chart_config = @chart_config)
    !chart_config.key?(config_key) || chart_config[config_key].nil? || chart_config[config_key] == :none
  end

  # this is a bit of a fudge, the data from a thermostatic scatter aggregation comes out
  # in the wrong order by default for most graphing packages, so the columns of data need
  # reorganising
  def reorganise_buckets
    dd_or_temp_key = @bucketed_data.key?(Series::DegreeDays::DEGREEDAYS) ? Series::DegreeDays::DEGREEDAYS : Series::Temperature::TEMPERATURE
    # replace dates on x axis with degree days, but retain them for future point labelling
    x_axis = @x_axis
    @x_axis = @bucketed_data[dd_or_temp_key]
    @x_axis_bucket_date_ranges = @xbucketor.x_axis_bucket_date_ranges # may not work? PH 7Oct2018
    @bucketed_data.delete(dd_or_temp_key)
    # insert dates back in as 'silent' y2_axis
    @data_labels = x_axis
  end

  # called only for scatter charts
  def add_x_axis_label
    @x_axis_label = @bucketed_data.key?(Series::DegreeDays::DEGREEDAYS) ? Series::DegreeDays::DEGREEDAYS : Series::Temperature::TEMPERATURE
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
    if !chart_has_filter?
      logger.info 'No filters set'
      return
    end
    ap(@bucketed_data, limit: 20, color: { float: :red }) if ENV['AWESOMEPRINT'] == 'on'
    logger.info "Filtering start #{@bucketed_data.keys}"
    logger.debug "Filters are: #{@chart_config[:filter].inspect}" 
    if @chart_config[:series_breakdown] == :submeter
      if @chart_config[:filter].key?(:submeter)
        keep_key_list += pattern_match_list_with_list(@bucketed_data.keys, @chart_config[:filter][:submeter])
      else
        keep_key_list += @bucketed_data.keys # TODO(PH,2Jul2018) may not be generic enough?
      end
    end
    if @chart_config[:filter].key?(:heating)
      raise EnergySparksBadChartSpecification, "Filter: :heating should always be true #{[:filter][:heating]}" unless @chart_config[:filter][:heating] == true
      filter = [Series::HeatingNonHeating::HEATINGDAY] # PH 22Mar2022 changed, uncertain of impact
      keep_key_list += pattern_match_list_with_list(@bucketed_data.keys, filter)
    end
    if @chart_config[:filter].key?(:model_type)
      # for model filters, copy in any trendlines for those models to avoid filtering 
      model_filter = [@chart_config[:filter][:model_type]].flatten(1)
      trendline_filters = model_filter.map { |model_name| Series::ManagerBase.trendline_for_series_name(model_name) }
      trendline_filters_with_parameters = pattern_match_two_symbol_lists(trendline_filters, @bucketed_data.keys)
      keep_key_list += pattern_match_list_with_list(@bucketed_data.keys, model_filter + trendline_filters_with_parameters)
    end
    %i[fuel daytype heating_daytype meter].each do |filter_type|
      if @chart_config[:filter].key?(filter_type)
        filtered_data = [@chart_config[:filter][filter_type]].flatten
        keep_key_list += pattern_match_list_with_list(@bucketed_data.keys, filtered_data)
      end
    end

    keep_key_list += pattern_match_y2_axis_names
    remove_list = []
    @bucketed_data.each_key do |series_name|
      remove_list.push(series_name) unless keep_key_list.include?(series_name)
    end

    remove_list.each do |remove_series_name|
      @bucketed_data.delete(remove_series_name)
    end
    # logger.debug ap(@bucketed_data, limit: 20, color: { float: :red }) if ENV['AWESOMEPRINT'] == 'on'
    logger.debug "Filtered End #{@bucketed_data.keys}"
  end

  # e.g. [:trendline_model_xyz] with [:trendline_model_xyz_a45_b67_r282] => [:trendline_model_xyz_a45_b67_r282]
  # only check for 'included in' not proper regexp
  # gets around problem with modifying bucket symbols before filtering
  def pattern_match_two_symbol_lists(match_symbol_list, symbol_list)
    matched_pairs = match_symbol_list.product(symbol_list).select { |match, sym| sym.to_s.include?(match.to_s) }
    matched_pairs.map { |match, symbol| symbol }
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
    @y2_axis = {}
    logger.debug "Moving #{@chart_config[:y2_axis]} onto Y2 axis"
    pattern_match_y2_axis_names.each do |series_name|
      @y2_axis[series_name] = @bucketed_data[series_name]
      @bucketed_data.delete(series_name)
    end
  end

  # need to deal with case where multiple merged charts and date or school suffix has been added to the end of the series name
  def pattern_match_y2_axis_names
    matched = []
    Series::ManagerBase.y2_series_types.values.each do |y2_series_name|
      base_name_length = y2_series_name.length
      matched += @bucketed_data.keys.select{ |bucket_name| bucket_name[0...base_name_length] == y2_series_name }
    end
    matched
  end

  def all_values_deprecated(obj)
    float_data = []
    find_all_floats(float_data, obj)
    float_data.empty? ? 0.0 : float_data.inject(:+)
  end

  # recursive search through hash/array for all float values
  def find_all_floats_deprecated(float_data, obj)
    if obj.is_a?(Hash)
      obj.each_value do |val|
        find_all_floats(float_data, val)
      end
    elsif obj.is_a?(Array)
      obj.each do |val|
        find_all_floats(float_data, val)
      end
    elsif obj.is_a?(Float)
      float_data.push(obj) unless obj.nan?
    else
      logger.info "Unexpected type #{val.class.name} to sum"
    end
  end

  def add_to_bucket(bucketed_data, bucketed_data_count, series_name, x_index, value)
    logger.warn "Unknown series name #{series_name} not in #{bucketed_data.keys}" if !bucketed_data.key?(series_name)
    logger.warn "nil value for #{series_name}" if value.nil?

    return if value.nil?

    if bucketed_data[series_name][x_index].nil?
      bucketed_data[series_name][x_index] = value
    else
      bucketed_data[series_name][x_index] += value
    end

    count = 1
    if add_daycount_to_legend?
      count = value != 0.0 ? 1 : 0
    end
    bucketed_data_count[series_name][x_index] += count # required to calculate kW
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
          @bucketed_data[series_name][index] /= @bucketed_data_count[series_name][index]
        end
      end
    end
  end

  def inject_benchmarks
    res = AggregatorResults.create(@bucketed_data, @bucketed_data_count, @x_axis, @x_axis_bucket_date_ranges, @y2_axis)
    bm = AggregatorBenchmarks.new(@meter_collection, @chart_config, res)
    bm.inject_benchmarks
    unpack_results(res)
  end

  def unpack_results(res)
    @bucketed_data, @bucketed_data_count, @x_axis, @x_axis_bucket_date_ranges, @y2_axis = res.unpack
  end
end
