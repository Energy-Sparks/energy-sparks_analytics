# some charts are created by combining multiple charts
# e.g. a chart compariing a school with benchmark and exemplar schools
#      is created by combining 3 charts 1 for each school
#      a school versus its target (school) combines 2 charts
# or   a chart compariing multiple time periods e.g. this year versus last year
class AggregatorMultiSchoolsPeriods < AggregatorBase
  class InternalErrorOnlyOneResultExpected < StandardError; end

  attr_reader :min_combined_school_date, :max_combined_school_date, :single_series_aggregators

  def initialize(school, chart_config, results)
    @single_series_aggregators = []
    super
  end

  def calculate
    determine_multi_school_chart_date_range # directly modifies chart_config

    res = run_charts_for_multiple_schools_and_time_periods(schools, periods)

    @results = selective_copy_of_first_results

    merge_charts

    res # TODO(PH, 1Apr2022) remove legacy refactor result return
  end

  def determine_multi_school_chart_date_range
    determine_multi_school_chart_date_range_private
  end

  def schools
    @schools ||= schools_list
  end

  def periods
    @periods ||= [chart_config.timescale].flatten
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
    single_series_aggregators.last.results.bucketless_result_copy
  end

  def number_of_periods
    periods.uniq.compact.length
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
      if single_series_aggregators.length != 1
        raise InternalErrorOnlyOneResultExpected, "Number of results = #{single_series_aggregators.length}"
      end

      results.bucketed_data       = single_series_aggregators.first.results.bucketed_data
      results.bucketed_data_count = single_series_aggregators.first.results.bucketed_data_count
    end
  end

  # monthly comparison charts e.g. electricity_cost_comparison_last_2_years_accounting
  # can be awkward as some years may occasionally have subtely different numbers of months e.g. 12 v. 13
  # so specific month date matching occurs to match one year with the next
  def merge_monthly_comparison_charts
    raise EnergySparksBadChartSpecification, 'More than one school not supported' if number_of_schools > 1

    x_axis = calculate_x_axis
    valid_aggregators.each do |period_data|
      time_description = number_of_periods <= 1 ? '' : period_data.results.xbucketor.compact_date_range_description

      # This series will have either the same number or fewer months than the other range
      #
      # If we have same number of months then we're comparing, e.g. two full year (52*7) week periods
      # So the columns are already aligned.
      #
      # If we have fewer months than the full range then we need to copy into a new array with the
      # monthly values in the right position.
      #
      # When we have fewer months then the months will correspond with the months at the final part of the
      # full range. So use the last occurence of the month name when finding the right index.
      if x_axis.length == period_data.results.x_axis.length
        data = period_data.results.bucketed_data.values[0]
        count_data = period_data.results.bucketed_data_count.values[0]
      else
        data = Array.new(x_axis.length, 0.0)
        count_data = Array.new(x_axis.length, 0)
        sub_array_index = find_sub_array_index(x_axis, remove_years(period_data.results.x_axis))
        if sub_array_index
          end_index = sub_array_index + period_data.results.x_axis.length
          data[sub_array_index...end_index] = period_data.results.bucketed_data.values[0]
          count_data[sub_array_index...end_index] = period_data.results.bucketed_data_count.values[0]
        end
      end
      results.bucketed_data[time_description] = data
      results.bucketed_data_count[time_description] = count_data
    end
    results.x_axis = x_axis
  end

  MONTHS = %w[Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec].freeze
  MONTHS_TO_I = MONTHS.each_with_index.to_h { |month, index| [month, index] }

  def calculate_x_axis
    axis_months = valid_aggregators.map { |aggregator| remove_years(aggregator.results.x_axis) }
    axis_months = axis_months.sort_by { |months| months.map { |month| MONTHS_TO_I[month] }.first }
    x_axis, *axis_months = axis_months
    axis_months.each do |months|
      x_axis += months.filter { |month| !x_axis.include?(month) }
    end
    x_axis
  end

  def remove_years(month_years)
    month_years.map { |month_year| month_year[0..2] }
  end

  def find_sub_array_index(array, sub_array)
    array.each_cons(sub_array.size).with_index { |cons, index| return index if cons == sub_array }
    nil
  end

  def valid_aggregators
    single_series_aggregators.select { |agg| agg.results.valid? }
  end

  def unique_periods
    @unique_periods ||= valid_aggregators.map { |agg| agg.results.time_description }.uniq.length
  end

  def merge_multiple_charts
    valid_aggregators.each do |data|
      time_description = unique_periods <= 1 ? '' : (':' + data.results.time_description)
      school_name = schools.nil? || schools.length <= 1 || data.results.school_name.nil? ? '' : (':' + data.results.school_name)
      school_name = '' if number_of_schools <= 1 # TODO(PH, 9May2022) is schools.length <= 1 test in line above sufficient?

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
    schools = chart_config.include_target? ? target_schools : [school]

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

  def determine_multi_school_chart_date_range_private
    extend_to_future = chart_config.include_target? && chart_config.extend_chart_into_future?

    logger.info '-' * 120
    logger.info "Determining maximum chart range for #{schools.length} schools:"

    min_date = schools.map do |school|
      Series::ManagerBase.new(school, chart_config).first_meter_date
    rescue EnergySparksNotEnoughDataException
      raise unless chart_config.ignore_single_series_failure?

      nil
    end.compact.max

    last_meter_dates = schools.map do |school|
      Series::ManagerBase.new(school, chart_config).last_meter_date
    rescue EnergySparksNotEnoughDataException
      raise unless chart_config.ignore_single_series_failure?

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
    schools.each do |school|
      # do it here so it maps to the 1st school
      temperature_adjustment_map(school)

      periods.reverse_each do |period| # do in reverse so final iteration represents the x-axis dates
        run_one_aggregation(period, school)
      rescue EnergySparksNotEnoughDataException
        raise unless chart_config.ignore_single_series_failure?
      end
    end
  end

  def run_one_aggregation(one_period, one_school)
    one_chart_config_hash = create_one_aggregation_chart_config(one_period, one_school)

    one_set_of_results = AggregatorResults.new

    ass = AggregatorSingleSeries.new(one_school, one_chart_config_hash, one_set_of_results)
    @single_series_aggregators.push(ass)

    ass.aggregate_period
  end

  def create_one_aggregation_chart_config(one_period, one_school)
    chartconfig_copy = chart_config.to_h.clone

    chartconfig_copy[:timescale] = one_period

    chartconfig_copy.merge!(chart_config.benchmark_override(one_school.name))

    chartconfig_copy
  end

  def temperature_adjustment_map(school)
    return unless chart_config.temperature_compensation_hash?

    chart_config.temperature_adjustment_map = temperature_compensation_temperature_map(school)
  end

  # for a chart_config e.g. :  {[ timescale: [ { schoolweek: 0 } , { schoolweek: -1 }, adjust_by_temperature:{ schoolweek: 0 } }
  # copy the corresponding temperatures from the :adjust_by_temperature onto all the corresponding :timescale periods
  # into a [date] => temperature hash
  # this allows in this example, for examples for all mondays to be compensated to the temperature of {schoolweek: 0}
  def temperature_compensation_temperature_map(school)
    unless chart_config.array_of_timescales?
      raise EnergySparksBadChartSpecification, 'Expected chart config timescale for array temperature compensation'
    end

    date_to_temperature_map = {}
    periods = chart_config.timescale
    chart_config_hash = chart_config.to_h
    periods.each do |period|
      chart_config_hash[:timescale] =
        date_to_temperature_map.empty? ? chart_config_hash[:adjust_by_temperature] : period
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
