# some charts are created by combining multiple charts
# e.g. a chart compariing a school with benchmark and exemplar schools
#      is created by combining 3 charts 1 for each school
#      a school versus its target (school) combines 2 charts
# or   a chart compariing multiple time periods e.g. this year versus last year
class AggregatorMultiSchoolsPeriods < AggregatorBase
  class InternalErrorOnlyOneResultExpected < StandardError; end

  attr_reader :periods, :schools
  attr_reader :min_combined_school_date, :max_combined_school_date
  attr_reader :single_series_aggregators
  attr_reader :multi_chart_x_axis_ranges # TODO(PH, 1Spr2022) remove post refactor

  def initialize(school, chart_config, results)
    @single_series_aggregators = []
    # results = new_results if results.nil?
    @multi_chart_x_axis_ranges = [] # TODO(PH, 1Apr2022) remove legacy refactor result return
    super(school, chart_config, results)
  end

  def calculate
    @schools = schools_list

    determine_multi_school_chart_date_range(schools) # directly modifies chart_config

    @periods = [chart_config.timescale].flatten

    res = run_charts_for_multiple_schools_and_time_periods(schools, periods)

    @results = selective_copy_of_first_results

    merge_charts

    res # TODO(PH, 1Apr2022) remove legacy refactor result return
  end

  def final_results
    single_series_aggregators.last.results
  end

  def series_manager
    final_results.series_manager
  end

  private

  # copy 1 example result apart from bucketed_data and bucketed_data_count
  # so the final returned results default x and y axis configration from 1
  # chart where there are mutliple charts, results for different time periods or
  # schools, so for example for multiple time periods the 1st result's x-axis is used
  def selective_copy_of_first_results
    # the results are calculated in reverse order (legacy design)
    res = single_series_aggregators.last.results.to_h.reject { |k, _v| %i[bucketed_data, bucketed_data_count].include?(k) }
    AggregatorResults.new(res)
  end

  def number_of_periods
    periods.uniq.length
  end

  def number_of_schools
    schools.map(&:name).uniq.length
  end

  def merge_charts
    results.bucketed_data       = {}
    results.bucketed_data_count = {}

    if chart_config.up_to_a_year_month_comparison?
      merge_monthly_comparison_charts
    elsif single_series_aggregators.length > 1 || number_of_periods > 1
      merge_multiple_charts
    else
      raise InternalErrorOnlyOneResultExpected, "Number of results = #{single_series_aggregators.length}" if single_series_aggregators.length != 1

      results.bucketed_data       = single_series_aggregators.first.results.bucketed_data
      results.bucketed_data_count = single_series_aggregators.first.results.bucketed_data_count
    end
  end

  def merge_monthly_comparison_charts
    raise EnergySparksBadChartSpecification, 'More than one school not supported' if number_of_schools > 1

    single_series_aggregators.reverse.with_index do |period_data, index|
      @multi_chart_x_axis_ranges.push(period_data.x_axis_date_ranges) # TODO(PH, 1Apr2022) remove after refactor not used

      if index == 0
        results.x_axis = period_data.results.x_axis.map{ |month_year| month_year[0..2]} # MMM YYYY to MMM
        results.bucketed_data[      time_description] = period_data.results.bucketed_data.values[0]
        results.bucketed_data_count[time_description] = period_data.results.bucketed_data_count.values[0]
      else
        time_description += "- partial year (from #{period_data.results[0]})" if period_data.results.x_axis.length < results.length

        keys = period_data.results.x_axis.map{ |month_year| month_year[0..2]}

        new_x_data = results.x_axis.map do |month|
          column = keys.find_index(month)
          column.nil? ? 0.0 : period_data.results.bucketed_data.values[0][column]
        end

        new_x_count_data = results.x_axis.map do |month|
          column = keys.find_index(month)
          column.nil? ? 0.0 : period_data.results.bucketed_data_count.values[0][column]
        end

        results.bucketed_data[time_description]       = new_x_data
        results.bucketed_data_count[time_description] = new_x_count_data
      end
    end
  end

  def merge_multiple_charts
    single_series_aggregators.each do |data|
      time_description = number_of_periods <= 1 ? '' : (':' + data.results.time_description)
      school_name = (schools.nil? || schools.length <= 1) ? '' : (':' + data.results.school_name)
      school_name = '' if number_of_schools <= 1

      @multi_chart_x_axis_ranges.push(data.results[:x_axis_date_ranges]) # TODO(PH, 1Apr2022) remove after refactor not used

      data.results.bucketed_data.each do |series_name, x_data|
        new_series_name = series_name.to_s + time_description + school_name
        results.bucketed_data[new_series_name] = x_data
      end

      data.results.bucketed_data_count.each do |series_name, count_data|
        new_series_name = series_name.to_s + time_description + school_name
        results.bucketed_data_count[new_series_name] = count_data
      end
    end
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

  def schools_list
    schools = chart_config.include_target? ? target_schools : [ school ]

    schools += benchmark_exemplar_schools_list if chart_config.include_benchmark?

    schools
  end

  def benchmark_exemplar_schools_list
    chart_config.benchmark_calculation_types.map do |calculation_type|
      school.benchmark_school(calculation_type)
    end
  end

  def target_schools
    target_school = school.target_school(chart_config.target_calculation_type)

    if chart_config.show_only_target_school?
      [target_school]
    else
      [school, target_school]
    end
  end

  def determine_multi_school_chart_date_range(schools)
    extend_to_future = chart_config.include_target? && chart_config.extend_chart_into_future?

    logger.info '-' * 120
    logger.info "Determining maximum chart range for #{schools.length} schools:"

    min_date = schools.map do |school|
      Series::ManagerBase.new(school, chart_config).first_meter_date
    rescue EnergySparksNotEnoughDataException => e_
      raise unless ignore_single_series_failure?
      nil
    end.compact.max

    last_meter_dates = schools.map do |school|
      Series::ManagerBase.new(school, chart_config).last_meter_date
    rescue EnergySparksNotEnoughDataException => e_
      raise unless ignore_single_series_failure?
      nil
    end.compact

    max_date = extend_to_future ? last_meter_dates.max : last_meter_dates.min

    if extend_to_future && %i[up_to_a_year year].include?(chart_config.timescale)
      # special case for targeting and tracking charts
      min_date = [min_date, max_date - 364].min
    end

    chart_config.min_combined_school_date = @min_combined_school_date = min_date
    chart_config.max_combined_school_date = @max_combined_school_date = max_date

    description = schools.length > 1 ? 'Combined school charts' : 'School chart'
    logger.info description + " date range #{min_date} to #{max_date}"
    logger.info '-' * 120
  end

  def run_charts_for_multiple_schools_and_time_periods(schools, periods)
    error_messages = []
    aggregations = []

    # iterate through the time periods aggregating
    schools.each do |school|
      # do it here so it maps to the 1st school
      temperature_adjustment_map(school)

      periods.reverse.each do |period| # do in reverse so final iteration represents the x-axis dates
        begin
          aggregations.push(
            {
              school:       school,
              period:       period,
              aggregation:  run_one_aggregation(period, school)
            }
          )
        rescue EnergySparksNotEnoughDataException => e_
          raise unless ignore_single_series_failure?
        end
      end
    end

    if (schools.length * periods.length) == error_messages.length
      raise EnergySparksNotEnoughDataException, 'All requested chart aggregations failed :' + error_messages.join(' + ')
    end

    aggregations = sort_aggregations(aggregations, sort_by) if chart_config.sort_by?

    aggregations.map { |aggregation_description| aggregation_description[:aggregation] }
  end

  def run_one_aggregation(one_period, one_school)
    one_chart_config_hash = create_one_aggregation_chart_config(one_period, one_school)

    one_set_of_results = AggregatorResults.new

    ass = AggregatorSingleSeries.new(one_school, one_chart_config_hash, one_set_of_results)
    @single_series_aggregators.push(ass)

    aggregate = ass.aggregate_period

    aggregate
  end

  def create_one_aggregation_chart_config(one_period, one_school)
    chartconfig_copy = chart_config.to_h.clone

    chartconfig_copy[:timescale] = one_period

    chartconfig_copy.merge!(chart_config.benchmark_override(one_school.name))

    chartconfig_copy
  end

  def temperature_adjustment_map(school)
    return if !chart_config.temperature_compensation_hash?

    chart_config.temperature_adjustment_map = temperature_compensation_temperature_map(school)
  end

  # for a chart_config e.g. :  {[ timescale: [ { schoolweek: 0 } , { schoolweek: -1 }, adjust_by_temperature:{ schoolweek: 0 } }
  # copy the corresponding temperatures from the :adjust_by_temperature onto all the corresponding :timescale periods
  # into a [date] => temperature hash
  # this allows in this example, for examples for all mondays to be compensated to the temperature of {schoolweek: 0}
  def temperature_compensation_temperature_map(school)
    raise EnergySparksBadChartSpecification, 'Expected chart config timescale for array temperature compensation' unless chart_config.array_of_timescales?

    date_to_temperature_map = {}
    periods = chart_config.timescale
    chart_config_hash = chart_config.to_h
    periods.each do |period|
      chart_config_hash[:timescale] = date_to_temperature_map.empty? ? chart_config_hash[:adjust_by_temperature] : period
      series_manager = Series::ManagerBase.new(school, chart_config_hash)
      if date_to_temperature_map.empty?
        series_manager.periods[0].dates.each do |date|
          date_to_temperature_map[date] = school.temperatures.average_temperature(date)
        end
      else
        subsequent_period_dates = series_manager.periods[0].dates
        subsequent_period_dates.each_with_index do |date, index|
          date_to_temperature_map[date] = date_to_temperature_map.values[index]
        end
      end
    end

    date_to_temperature_map
  end

  def new_results_deprecated
    results = AggregatorResults.new
    results.bucketed_data = {}
    results.bucketed_data_count = {}
    results
  end
end
