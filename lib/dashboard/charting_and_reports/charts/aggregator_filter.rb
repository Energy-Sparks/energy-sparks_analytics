# filters can be applied either pre or post calculation depending on expedience/performance
# so pre-filters determine in advice whether something needs calculating and then don't calculate
# post-filters - do the calculation and then removes results before passing back fro display
class AggregatorFilter < AggregatorBase
  attr_reader :filter
  def initialize(school, chart_config, results)
    super(school, chart_config, results)
  end

  # pre-filter
  def match_filter_by_day(date)
    # heating_daytype filter gets filtered out post aggregation, reduced performance but simpler
    return true if !chart_config.chart_has_filter?
    return true if chart_config.heating_daytype_filter?
    return true if chart_config.submeter_filter?

    match_daytype = match_occupied_type_filter_by_day(date) if chart_config.daytype_filter?
    match_heating = true
    match_heating = match_filter_by_heatingdayday(date) if chart_config.heating_filter?
    match_model = true
    match_model = match_filter_by_model_type(date) if chart_config.model_type_filter?
    match_daytype && match_heating && match_model
  end

  # pre-filter
  def match_filter_by_heatingdayday(date)
    chart_config.heating_filter == results.series_manager.heating_model.heating_on?(date)
  end

  # pre-filter
  def match_filter_by_model_type(date)
    model_list = chart_config.model_type_filters
    model_list = [ model_list ] if model_list.is_a?(Symbol) # convert to array if not an array
    model_list.include?(results.series_manager.heating_model.model_type?(date))
  end

  # pre-filter
  def match_occupied_type_filter_by_day(date)
    filter = chart_config.day_type_filter
    holidays = school.holidays
    match = false
    [filter].flatten.each do |one_filter|
      case one_filter
      when Series::DayType::HOLIDAY
        match ||= true if holidays.holiday?(date)
      when Series::DayType::WEEKEND
        match ||= true if DateTimeHelper.weekend?(date) && !holidays.holiday?(date)
      when Series::DayType::SCHOOLDAYOPEN, Series::DayType::SCHOOLDAYOPEN
        match ||= true if !(DateTimeHelper.weekend?(date) || holidays.holiday?(date))
      end
    end
    match
  end

  # post-filter
  def remove_filtered_series
    keep_key_list = []
    if !chart_config.chart_has_filter?
      logger.info 'No filters set'
      return
    end

    logger.info "Filtering start #{results.bucketed_data.keys}"
    logger.debug "Filters are: #{chart_config.filters}" 
    if chart_config.series_breakdown == :submeter
      if chart_config.submeter_filter?
        keep_key_list += pattern_match_list_with_list(results.bucketed_data.keys, @hart_config.submeter_filter)
      else
        keep_key_list += results.bucketed_data.keys
      end
    end
    if chart_config.heating_filter?
      filter = [Series::HeatingNonHeating::HEATINGDAY]
      keep_key_list += pattern_match_list_with_list(results.bucketed_data.keys, filter)
    end
    if chart_config.model_type_filter?
      # for model filters, copy in any trendlines for those models to avoid filtering 
      model_filter = [chart_config.model_type_filters].flatten(1)
      trendline_filters = model_filter.map { |model_name| Series::ManagerBase.trendline_for_series_name(model_name) }
      trendline_filters_with_parameters = pattern_match_two_symbol_lists(trendline_filters, results.bucketed_data.keys)
      keep_key_list += pattern_match_list_with_list(results.bucketed_data.keys, model_filter + trendline_filters_with_parameters)
    end
    %i[fuel daytype heating_daytype meter].each do |filter_type|
      if chart_config.has_filter?(filter_type)
        filtered_data = [chart_config.filter_by_type(filter_type)].flatten
        keep_key_list += pattern_match_list_with_list(results.bucketed_data.keys, filtered_data)
      end
    end

    keep_key_list += pattern_match_y2_axis_names
    remove_list = []
    results.bucketed_data.each_key do |series_name|
      remove_list.push(series_name) unless keep_key_list.include?(series_name)
    end

    remove_list.each do |remove_series_name|
      results.bucketed_data.delete(remove_series_name)
    end

    logger.debug "Filtered End #{results.bucketed_data.keys}"
  end

  def pattern_match_list_with_list(list, pattern_list)
    filtered_list = []
    pattern_list.each do |pattern|
      pattern_matched_list = list.select{ |i| i == pattern }
      filtered_list += pattern_matched_list unless pattern_matched_list.empty?
    end
    filtered_list
  end

  def pattern_match_y2_axis_names
    matched = []
    Series::ManagerBase.y2_series_types.values.each do |y2_series_name|
      base_name_length = y2_series_name.length
      matched += results.bucketed_data.keys.select{ |bucket_name| bucket_name[0...base_name_length] == y2_series_name }
    end
    matched
  end

  # e.g. [:trendline_model_xyz] with [:trendline_model_xyz_a45_b67_r282] => [:trendline_model_xyz_a45_b67_r282]
  # only check for 'included in' not proper regexp
  # gets around problem with modifying bucket symbols before filtering
  def pattern_match_two_symbol_lists(match_symbol_list, symbol_list)
    matched_pairs = match_symbol_list.product(symbol_list).select { |match, sym| sym.to_s.include?(match.to_s) }
    matched_pairs.map { |match, symbol| symbol }
  end
end
