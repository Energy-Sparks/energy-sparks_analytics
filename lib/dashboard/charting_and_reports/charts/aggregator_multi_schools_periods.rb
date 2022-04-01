# some charts are created by combining multiple charts
# e.g. a chart compariing a school with benchmark and exemplar schools
#      is created by combining 3 charts 1 for each school
#      a school versus its target (school) combines 2 charts
# or   a chart compariing multiple time periods e.g. this year versus last year
class AggregatorMultiSchoolsPeriods < AggregatorBase
  attr_reader :series_manager, :final_results

  def calculate
    schools = schools_list

    determine_multi_school_chart_date_range(schools) # directly modifies chart_config

    periods = [chart_config.timescale].flatten

    run_charts_for_multiple_schools_and_time_periods(schools, periods)
  end

  private

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

    chart_config.min_combined_school_date = min_date
    chart_config.max_combined_school_date = max_date

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
    aggregate = ass.aggregate_period

    @series_manager = ass.results.series_manager # TODO(PH, 1Apr2022) remove after refactor, backwards compatibility
    @final_results  = ass.results                # TODO(PH, 1Apr2022) remove after refactor, backwards compatibility

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
end
