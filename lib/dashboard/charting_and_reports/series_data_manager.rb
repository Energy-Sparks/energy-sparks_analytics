# Series Data Manager
# - acts as a single interface for all requests from the aggregation process
# - and other sources e.g. alerts for all energy related data
#
# sources of data:
#   - raw smart meter/amr data on half hour boundaries, could be electricity or gas
#   - slightly more derived versions of that data, for example storage heaters, typically auto split
#     from electricity data (on meter becomes 2)
#   - simplistic modelled data e.g. baseload
#   - more sophisticated model data e.g. hot water (useful, non-useful usage),
#     multiple regression model(predicted heating kWh, difference with actual)
#   - temperature data, and derived degree days (base temperature)
#
# breakdown of returned data:
#   - by time of day (weekend, holiday, school day in school hours, school day out of hours)
#   - by fuel (gas, electricity) through to (gas, electricity, storage heater, solar pv)
#   - cusum model split (monday versus all week predictions etc.), trend line data
#
# unit conversion
#   - kWh
#   - kW - needs averaging if aggregated
#   - cost (ultimately to include time of day/economy 7 pricing)
#   - CO2
# unit normalisation
#   - per pupil
#   - per floor
# unit normalisation 2
#   - degree day adjustment
#
# time period
#   - single day
#   - single half hour for example in intraday reporting
#   - time periods - on date boundaries only
#

# single location containing text name of each series which appears in chart legend
class SeriesNames
  HEATINGDAY      = 'Heating Day'.freeze
  NONHEATINGDAY   = 'Non Heating Day'.freeze
  HEATINGSERIESNAMES = [HEATINGDAY.freeze, NONHEATINGDAY.freeze].freeze

  HEATINGDAYMODEL      = 'Heating Day Model'.freeze
  NONHEATINGDAYMODEL   = 'Non Heating Day Model'.freeze
  HEATINGMODELSERIESNAMES = [HEATINGDAYMODEL.freeze, NONHEATINGDAYMODEL.freeze].freeze

  HOLIDAY         = 'Holiday'.freeze
  WEEKEND         = 'Weekend'.freeze
  SCHOOLDAYOPEN   = 'School Day Open'.freeze
  SCHOOLDAYCLOSED = 'School Day Closed'.freeze
  DAYTYPESERIESNAMES = [HOLIDAY.freeze, WEEKEND.freeze, SCHOOLDAYOPEN.freeze, SCHOOLDAYCLOSED.freeze].freeze

  DEGREEDAYS      = 'Degree Days'.freeze
  TEMPERATURE     = 'Temperature'.freeze
  IRRADIANCE      = 'Solar Irradiance'.freeze
  GRIDCARBON      = 'Grid Carbon Intensity'.freeze

  PREDICTEDHEAT   = 'Predicted Heat'.freeze
  CUSUM           = 'CUSUM'.freeze
  BASELOAD        = 'BASELOAD'.freeze

  USEFULHOTWATERUSAGE = 'Hot Water Usage'.freeze
  WASTEDHOTWATERUSAGE = 'Wasted Hot Water Usage'.freeze
  HOTWATERSERIESNAMES = [WASTEDHOTWATERUSAGE.freeze, USEFULHOTWATERUSAGE.freeze].freeze

  NONE            = 'Energy'.freeze

  def self.y2_axis_key(axis_sym, throw_exception = true)
    case axis_sym
    when :degreedays
      DEGREEDAYS
    when :temperature
      TEMPERATURE
    when :irradiance
      IRRADIANCE
    when :gridcarbon
      GRIDCARBON
    else
      if throw_exception
        if axis_sym.nil?
          throw EnergySparksBadChartSpecification.new('nil y2 axis specification')
        else
          throw EnergySparksBadChartSpecification.new("unknown y2 axis specification #{axis_sym}")
        end
      else
        nil
      end
    end
  end

  # plus dynamically generated names, for example meter names
end

class SeriesDataManager
  include Logging

  attr_reader :first_meter_date, :last_meter_date, :first_chart_date, :last_chart_date, :periods

  def initialize(meter_collection, chart_configuration)
    @meter_collection = meter_collection
    @meter_definition = chart_configuration[:meter_definition]
    @breakdown_list = convert_variable_to_array(chart_configuration[:series_breakdown])
    @y2_axis_list = convert_variable_to_array(chart_configuration[:y2_axis])
    @data_types = convert_variable_to_array(chart_configuration[:data_types])
    @heating_model = nil
    @hotwater_model = nil
    @periods = nil
    @chart_configuration = chart_configuration
    configure_manager
    logger.info "Series Name Manager: Chart Creation for #{meter_collection}"
  end

  def convert_variable_to_array(value)
    if value.is_a?(Array)
      value
    else
      [value]
    end
  end

  # list of series buckets: supports combinations => potential combinatorial explosion!
  def series_bucket_names
    @series_buckets = []
    if @breakdown_list.include?(:fuel)
      @meters.each do |meter|
        if meter.nil?
          @series_buckets.push('gas') # TODO(PH,17Jun2018) meter selection needs fixing
        else
          fuel_type = meter.fuel_type.to_s

          # aggregated meters can either be of aggregated type, or if only one meter then non-aggregate version
          # TODO(PH,29Sep2018) consider whether to what symbology to use for aggregate meters on loading?
          fuel_type = 'electricity' if fuel_type == 'aggregated_electricity'
          fuel_type = 'gas' if fuel_type == 'aggregated_heat'

          @series_buckets.push(fuel_type)
        end
      end
    end
    if @breakdown_list.include?(:heating)
      @series_buckets = combinatorially_combine(@series_buckets, SeriesNames::HEATINGSERIESNAMES)
    end
    if @breakdown_list.include?(:daytype)
      @series_buckets = combinatorially_combine(@series_buckets, SeriesNames::DAYTYPESERIESNAMES)
    end
    if @breakdown_list.include?(:heatingmodeltrendlines)
      @series_buckets += SeriesNames::HEATINGMODELSERIESNAMES
    end
    if @breakdown_list.include?(:submeter)
      @series_buckets += submeter_names
    end
    if @breakdown_list.include?(:hotwater)
      @series_buckets += SeriesNames::HOTWATERSERIESNAMES
    end
    if @breakdown_list.include?(:meter)
      @series_buckets += meter_names
    end
    if @breakdown_list.include?(:none)
      @series_buckets.push(SeriesNames::NONE)
    end
    if @breakdown_list.include?(:cusum)
      @series_buckets.push(SeriesNames::CUSUM)
    end
    if @breakdown_list.include?(:baseload)
      @series_buckets.push(SeriesNames::BASELOAD)
    end
    if @y2_axis_list.include?(:degreedays) || @breakdown_list.include?(:degreedays)
      @series_buckets.push(SeriesNames::DEGREEDAYS)
    end
    if @y2_axis_list.include?(:temperature) || @breakdown_list.include?(:temperature)
      @series_buckets.push(SeriesNames::TEMPERATURE)
    end
    if @y2_axis_list.include?(:irradiance) || @breakdown_list.include?(:irradiance)
      @series_buckets.push(SeriesNames::IRRADIANCE)
    end
    if @y2_axis_list.include?(:gridcarbon) || @breakdown_list.include?(:gridcarbon)
      @series_buckets.push(SeriesNames::GRIDCARBON)
    end
    if @data_types.include?(:predictedheat) # not sure this is the best final resting place for this test?
      @series_buckets.push(SeriesNames::PREDICTEDHEAT)
    end
    @series_buckets
  end

  def get_data(time_period)
    begin
      get_data_private(time_period)
    rescue StandardError => ee
      _timetype, dates, _halfhour_index = time_period
      if !dates.is_a?(Array) || dates[0].nil? || dates[1].nil?
        logger.error "Error: getting data for time period #{time_period}"
      else
        start_date_str = dates[0].strftime('%d %m %Y')
        end_date_str = dates[1].strftime('%d %m %Y')
        logger.error "Error: getting data for time period #{start_date_str} to #{end_date_str}"
      end
      logger.error ee.message
      logger.error ee.backtrace
    end
  end

  def submeter_names
    meter = select_one_meter
    submeter_names = []
    meter.sub_meters.each do |submeter|
      submeter_names.push(submeter.name)
    end
    submeter_names
  end

  def meter_names
    names = []
    if !@meters[0].nil? # indication of heat meters only
      names += meter_names_from_list(@meter_collection.electricity_meters)
      names += meter_names_from_list(@meter_collection.solar_pv_meters)
    end
    if !@meters[1].nil? # indication of heat meters only
      names += meter_names_from_list(@meter_collection.heat_meters)
      names += meter_names_from_list(@meter_collection.storage_heater_meters)
    end
    names
  end

  # TODO(PH,16Sep2018) - this function is called repetatively - list should be cached
  def meter_names_from_list(list_of_meters)
    list = []
    list_of_meters.each do |meter|
      list.push(meter.display_name)
    end
    list
  end

  def get_data_private(time_period)
    # TODO(PH,22May2018): support combinations of series as per above series_bucket_names method

    timetype, dates, halfhour_index = time_period
    meter = select_one_meter
    breakdown = {}
    case timetype
    when :oneday
      if @breakdown_list.include?(:daytype)
        breakdown = daytype_breakdown([dates, dates], meter)
        raise "Currently not implemented, use :daterange instead same day to same day in range"
      end
    when :halfhour, :datetime
      date = dates # a single date in an intraday case, so disambiguate
      if @breakdown_list.include?(:submeter)
        meter.sub_meters.each do |submeter|
          breakdown[submeter.name] = submeter.amr_data.kwh(date, halfhour_index)
        end
      elsif @breakdown_list.include?(:meter)
        breakdown = breakdown_to_meter_level(date, date, halfhour_index)
      elsif @breakdown_list.include?(:fuel)
        breakdown = fuel_breakdown_halfhour(date, halfhour_index)
      elsif @breakdown_list.include?(:daytype)
        breakdown = daytype_breakdown_halfhour(date, halfhour_index, meter)
      else
        breakdown[SeriesNames::NONE] = meter.amr_data.kwh(date, halfhour_index)
      end
      if @y2_axis_list.include?(:degreedays) || @breakdown_list.include?(:degreedays)
        breakdown[SeriesNames::DEGREEDAYS] = @meter_collection.temperatures.degree_hour(date, halfhour_index, 20.0)
      end
      if @y2_axis_list.include?(:temperature) || @breakdown_list.include?(:temperature)
        breakdown[SeriesNames::TEMPERATURE] = @meter_collection.temperatures.temperature(date, halfhour_index)
      end
      if @y2_axis_list.include?(:irradiance) || @breakdown_list.include?(:irradiance)
        breakdown[SeriesNames::IRRADIANCE] = @meter_collection.solar_irradiation.solar_irradiance(date, halfhour_index)
      end
      if @y2_axis_list.include?(:gridcarbon) || @breakdown_list.include?(:gridcarbon)
        breakdown[SeriesNames::GRIDCARBON] = @meter_collection.grid_carbon_intensity.grid_carbon_intensity(date, halfhour_index)
      end
    when :daterange
      if @breakdown_list.include?(:daytype)
        breakdown = daytype_breakdown([dates[0], dates[1]], meter)
      end
      if @breakdown_list.include?(:fuel)
        breakdown = fuel_breakdown([dates[0], dates[1]], @meters[0], @meters[1])
      end
      if @breakdown_list.include?(:heating)
        calculate_model if @heating_model.nil?
        breakdown = heating_breakdown([dates[0], dates[1]], @meters[0], @meters[1])
      end
      if @breakdown_list.include?(:cusum)
        calculate_model if @heating_model.nil?
        model_kwh = @heating_model.predicted_kwh_daterange(dates[0], dates[1], @meter_collection.temperatures)
        actual_kwh = meter.amr_data.kwh_date_range(dates[0], dates[1])
        breakdown[SeriesNames::CUSUM] = model_kwh - actual_kwh
      end
      if @breakdown_list.include?(:hotwater)
        hotwater_model = calculate_hotwater_model
        useful_kwh, wasted_kwh = hotwater_model.kwh_daterange(dates[0], dates[1])
        breakdown[SeriesNames::USEFULHOTWATERUSAGE] = useful_kwh
        breakdown[SeriesNames::WASTEDHOTWATERUSAGE] = wasted_kwh
      end
      if @breakdown_list.include?(:baseload)
        baseload = meter.amr_data.baseload_kwh_date_range(dates[0], dates[1]) * 24 # TODO(PH,6Jun2018) rationalise kW as *24 to offset /24 in aggregator
        breakdown[SeriesNames::BASELOAD] = baseload
      end
      if @breakdown_list.include?(:submeter)
        meter.sub_meters.each do |submeter|
          breakdown[submeter.name] = submeter.amr_data.kwh_date_range(dates[0], dates[1])
        end
      end
      if @breakdown_list.include?(:meter)
        breakdown = breakdown_to_meter_level(dates[0], dates[1])
      end
      if @breakdown_list.include?(:none)
        breakdown[SeriesNames::NONE] = meter.amr_data.kwh_date_range(dates[0], dates[1])
      end
      if @breakdown_list.include?(:heatingmodeltrendlines)
        calculate_model if @heating_model.nil?
        breakdown = breakdown.merge(predicted_heating_breakdown([dates[0], dates[1]], @meters[0], @meters[1]))
      end
      if @y2_axis_list.include?(:degreedays) || @breakdown_list.include?(:degreedays)
        breakdown[SeriesNames::DEGREEDAYS] = @meter_collection.temperatures.degrees_days_average_in_range(20.0, dates[0], dates[1])
      end
      if @y2_axis_list.include?(:temperature) || @breakdown_list.include?(:temperature)
        breakdown[SeriesNames::TEMPERATURE] = @meter_collection.temperatures.average_temperature_in_date_range(dates[0], dates[1])
      end
      if @y2_axis_list.include?(:irradiance) || @breakdown_list.include?(:irradiance)
        breakdown[SeriesNames::IRRADIANCE] = @meter_collection.solar_irradiation.average_in_date_range(dates[0], dates[1])
      end
      if @y2_axis_list.include?(:gridcarbon) || @breakdown_list.include?(:gridcarbon)
        breakdown[SeriesNames::GRIDCARBON] = @meter_collection.grid_carbon_intensity.average_in_date_range(dates[0], dates[1])
      end
      if @data_types.include?(:predictedheat)
        calculate_model if @heating_model.nil?
        model_kwh = @heating_model.predicted_kwh_daterange(dates[0], dates[1], @meter_collection.temperatures)
        breakdown[SeriesNames::PREDICTEDHEAT] = model_kwh
      end
    end
    breakdown
  end

  def heating_model
    calculate_model if @heating_model.nil?
    @heating_model
  end

private

  def scaling_factor(_value, fuel_type)
    y_scaling = YAxisScaling.new # perhaps shouldn't be class, maybe just a method?
    y_scaling.scale_from_kwh(1.0, @chart_configuration[:yaxis_units], @chart_configuration[:yaxis_scaling], fuel_type, @meter_collection)
  end

  # combinatorially combine 2 arrays of series names
  def combinatorially_combine(set_one, set_two)
    if set_one.empty?
      set_two.dup
    elsif set_two.empty?
      set_one.dup
    else
      all_keys = []
      set_one.each do |one|
        set_two.each do |two|
          all_keys.push(one + ': ' + two)
        end
      end
      all_keys
    end
  end

  def calculate_model
    # model calculated using the latest year's regression data,deliberately ignores chart request
    periods = @meter_collection.holidays.years_to_date(@first_meter_date, @last_meter_date, false)
    @heating_model = @meter_collection.heating_model(periods[0])
    @heating_model.calculate_heating_periods(first_chart_date, last_chart_date)
  end

  def calculate_hotwater_model
    @hotwater_model = AnalyseHeatingAndHotWater::HotwaterModel.new(@meter_collection) if @hotwater_model.nil?
    @hotwater_model
  end

   # TODO(PH,22May2018) meter selection needs revisiting
  def select_one_meter
    if @meters[0].nil?
      @meters[1]
    else
      @meters[0]
    end
  end

  def daytype_breakdown(date_range, meter)
    factor = scaling_factor(1.0, meter.fuel_type) # lookup once for performance

    daytype_data = {
      SeriesNames::HOLIDAY => 0.0,
      SeriesNames::WEEKEND => 0.0,
      SeriesNames::SCHOOLDAYOPEN => 0.0,
      SeriesNames::SCHOOLDAYCLOSED => 0.0
    }
    (date_range[0]..date_range[1]).each do |date|
      begin
        if @meter_collection.holidays.holiday?(date)
          daytype_data[SeriesNames::HOLIDAY] += meter.amr_data.one_day_kwh(date) * factor
        elsif DateTimeHelper.weekend?(date)
          daytype_data[SeriesNames::WEEKEND] += meter.amr_data.one_day_kwh(date) * factor
        else
          (0..47).each do |halfhour_index|
            # Time is an order of magnitude slower than DateTime on Windows
            dt = DateTime.new(date.year, date.month, date.day, (halfhour_index / 2).floor.to_i, (halfhour_index % 2).even? ? 0 : 30, 0)
            daytype_type = @meter_collection.school_day_in_hours(dt) ? SeriesNames::SCHOOLDAYOPEN : SeriesNames::SCHOOLDAYCLOSED
            daytype_data[daytype_type] += meter.amr_data.kwh(date, halfhour_index) * factor
          end
        end
      rescue StandardError => _e
        logger.error "Unable to aggregate data for #{date} - exception raise"
      end
    end
    daytype_data
  end

  def daytype_breakdown_halfhour(date, halfhour_index, meter)
    factor = scaling_factor(1.0, meter.fuel_type) # lookup once for performance
    val = meter.amr_data.kwh(date, halfhour_index) * factor

    daytype_data = {
      SeriesNames::HOLIDAY => 0.0,
      SeriesNames::WEEKEND => 0.0,
      SeriesNames::SCHOOLDAYOPEN => 0.0,
      SeriesNames::SCHOOLDAYCLOSED => 0.0
    }

    if @meter_collection.holidays.holiday?(date)
      daytype_data[SeriesNames::HOLIDAY] = val
    elsif DateTimeHelper.weekend?(date)
      daytype_data[SeriesNames::WEEKEND] = val
    else
      dt = DateTimeHelper.datetime(date, halfhour_index)
      daytype_type = @meter_collection.school_day_in_hours(dt) ? SeriesNames::SCHOOLDAYOPEN : SeriesNames::SCHOOLDAYCLOSED
      daytype_data[daytype_type] = val
    end

    daytype_data
  end

  def breakdown_to_meter_level(start_date, end_date, halfhour_index = nil)
    breakdown = {}
    meter_names.each do |meter_name|
      breakdown[meter_name] = 0.0
    end
    unless @meters[0].nil? # indication of electricity only 
      breakdown = merge_breakdown(breakdown, breakdown_one_meter_type(@meter_collection.electricity_meters, start_date, end_date, halfhour_index))
      breakdown = merge_breakdown(breakdown, breakdown_one_meter_type(@meter_collection.solar_pv_meters, start_date, end_date, halfhour_index))
    end
    unless @meters[1].nil? # indication of heat meters only
      breakdown = merge_breakdown(breakdown, breakdown_one_meter_type(@meter_collection.heat_meters, start_date, end_date, halfhour_index))
      breakdown = merge_breakdown(breakdown, breakdown_one_meter_type(@meter_collection.storage_heater_meters, start_date, end_date, halfhour_index))
    end
    breakdown
  end

  def breakdown_one_meter_type(list_of_meters, start_date, end_date, halfhour_index = nil)
    breakdown = {}
    unless list_of_meters.nil?
      list_of_meters.each do |meter|
        begin
          if halfhour_index.nil?
            breakdown[meter.display_name] = meter.amr_data.kwh_date_range(start_date, end_date)
          else
            breakdown[meter.display_name] = 0.0
            (start_date..end_date).each do |date|
              breakdown[meter.display_name] = meter.amr_data.kwh(date, halfhour_index)
            end
          end
        rescue Exception => e
          logger.error "Failure getting meter breakdown data for #{meter.display_name} between #{start_date} and #{end_date}"
          logger.error e.message
        end
      end
    end
    breakdown
  end

  def merge_breakdown(breakdown1, breakdown2)
    breakdown = breakdown1.clone
    breakdown2.each do |series_name, kwh|
      if breakdown.key?(series_name)
        breakdown[series_name] += breakdown2[series_name]
      else
        breakdown[series_name]  = breakdown2[series_name]
      end
    end
    breakdown
  end

  def fuel_breakdown(date_range, electricity_meter, gas_meter)
    electric_factor = scaling_factor(1.0, :electricity) # lookup once for performance
    gas_factor = scaling_factor(1.0, :gas) # lookup once for performance
    # solar_pv_factor = scaling_factor(1.0, :solar_pv)
    # storage_heater_factor = scaling_factor(1.0, :storage_heater)
    fuel_data = {
      'electricity' => 0.0,
      'gas' => 0.0
      # 'solar pv' => 0.0,
      # 'storage heaters' => 0.0
    }
    (date_range[0]..date_range[1]).each do |date|
      begin
        if gas_meter.nil?
          fuel_data['gas'] += 0.0
        else
          fuel_data['gas'] += gas_meter.amr_data.one_day_kwh(date) * gas_factor
        end
        if electricity_meter.nil?
          fuel_data['electricity'] += 0.0
        else
          fuel_data['electricity'] += electricity_meter.amr_data.one_day_kwh(date) * electric_factor
        end
        # fuel_data['solar pv'] += solar_pv_meter.amr_data.one_day_kwh(date) * solar_pv_factor
        # fuel_data['storage heaters'] += storage_meter.amr_data.one_day_kwh(date) * storage_heater_factor
      rescue Exception => e
        logger.error "Missing or nil data on #{date}"
        logger.error e
      end
    end
    fuel_data
  end

  def fuel_breakdown_halfhour(date, halfhour_index)
    electric_factor = scaling_factor(1.0, :electricity)
    electricity_meter = @meters[0]
    electric_val = electricity_meter.nil? ? 0.0 : (electricity_meter.amr_data.kwh(date, halfhour_index) * electric_factor)

    gas_factor = scaling_factor(1.0, :gas)
    gas_meter = @meters[1]
    gas_val = gas_meter.nil? ? 0.0 : (gas_meter.amr_data.kwh(date, halfhour_index) * gas_factor)

    fuel_data = {
      'electricity' => electric_val,
      'gas' => gas_val
    }

    fuel_data
  end

  def heating_breakdown(date_range, _electricity_meter, heat_meter)
    factor = scaling_factor(1.0, heat_meter.fuel_type) # lookup once for performance
    heating_data = { SeriesNames::HEATINGDAY => 0.0, SeriesNames::NONHEATINGDAY => 0.0 }
    (date_range[0]..date_range[1]).each do |date|
      begin
        type = @heating_model.heating_on?(date) ? SeriesNames::HEATINGDAY : SeriesNames::NONHEATINGDAY
        heating_data[type] += heat_meter.amr_data.one_day_kwh(date) * factor
      rescue StandardError => e
        logger.error e.message
        logger.error "Warning: unable to calculate heating breakdown on #{date}"
      end
    end
    heating_data
  end

  def predicted_heating_breakdown(date_range, _electricity_meter, heat_meter)
    factor = scaling_factor(1.0, heat_meter.fuel_type) # lookup once for performance
    heating_data = { SeriesNames::HEATINGDAYMODEL => 0.0, SeriesNames::NONHEATINGDAYMODEL => 0.0 }
    (date_range[0]..date_range[1]).each do |date|
      begin
        type = @heating_model.heating_on?(date) ? SeriesNames::HEATINGDAYMODEL : SeriesNames::NONHEATINGDAYMODEL
        avg_temp = @meter_collection.temperatures.average_temperature(date)
        heating_data[type] += @heating_model.predicted_kwh(date, avg_temp) * factor
      rescue StandardError => e
        logger.error "Missing or nil predicted heating data on #{date}"
        logger.error e
        logger.error e.backtrace
      end
    end
    heating_data
  end

  def configure_manager
    configure_meters
    @first_meter_date = calculate_first_meter_date
    @last_meter_date = calculate_last_meter_date
    calculate_periods
    calculate_first_chart_date
    calculate_last_chart_date
  end

  # the timescale parameter comes from the 'chart_configuration' and helps define the
  # arrangement or grouping of dates along the x-axis
  # the parameter is heavingly overloaded, it can deal with a variety of values:
  # :academic_year
  # :year             - implies the current year to date i.e. using the lastest data
  # :week
  # and then these parameters are then overloaded as either hashes or arrays, for example
  # {:week => Date.new(2018, 6, 1)}              # calculate a chart for a week ending 1Jun2018
  # [{:week => 0}, {:week => -1}, {:week => -2}] # compare the last 3 weeks data

  def calculate_periods
    if @chart_configuration.key?(:timescale) && @chart_configuration[:timescale].is_a?(Symbol)
      case @chart_configuration[:timescale]
      when :academicyear
        periods = @meter_collection.holidays.academic_years(@first_meter_date, @last_meter_date)
        @periods = [periods[0]]
      when :year
        periods = @meter_collection.holidays.years_to_date(@first_meter_date, @last_meter_date, false)
        @periods = [periods[0]]
      when :week
        period = SchoolDatePeriod.new(:week, 'current week', @last_meter_date - 6, @last_meter_date)
        @periods = [period]
      else
        raise "Unsupported time period for charting #{@chart_configuration[:timescale]}"
      end
    elsif @chart_configuration.key?(:timescale) && @chart_configuration[:timescale].is_a?(Hash)
      hash_key, hash_value = @chart_configuration[:timescale].first
      case hash_key
      when :academicyear
        periods = @meter_collection.holidays.academic_years(@first_meter_date, @last_meter_date)
        if hash_value.is_a?(Integer)
          raise 'Error: expecting zero of negative number for academic year specification' if hash_value > 0
          raise EnergySparksMissingPeriodForSpecifiedPeriodChart.new("Error: data not available for #{hash_value}th academic year") if hash_value.magnitude > periods.length - 1
          @periods = [periods[hash_value.magnitude]]
        else
          raise "Expecting an integer as an parameter for an academic year specification got a #{hash_value.class.name}"
        end
      when :year
        if hash_value.is_a?(Integer)
          raise 'Error: expecting zero or negative number for year specification' if hash_value > 0
          periods = @meter_collection.holidays.years_to_date(@first_meter_date, @last_meter_date, false)
          raise EnergySparksMissingPeriodForSpecifiedPeriodChart.new("Error: data not available for #{hash_value}th year") if hash_value.magnitude > periods.length - 1
          @periods = [periods[hash_value.magnitude]]
        elsif hash_value.is_a?(Date)
          end_date = hash_value > @last_meter_date ? @last_meter_date : hash_value
          @periods = @meter_collection.holidays.years_to_date(@first_meter_date, end_date, false)
        else
          raise "Expecting an integer or date as an parameter for a year specification got a #{hash_value.class.name}"
        end
      when :week
        if hash_value.is_a?(Integer) # hash_value weeks back from latest week
          raise 'Error: expecting zero of negative number for week specification' if hash_value > 0
          end_date = @last_meter_date - 7 * hash_value.magnitude
          start_date = end_date - 6
          if start_date < @first_meter_date
            raise "Error: date request for week of data out of range start date #{start_date} before first meter data #{@first_meter_date}"
          else
            period = SchoolDatePeriod.new(:week, 'current week', start_date, end_date)
          end
        elsif hash_value.is_a?(Date) # assume in this case the specified date is the first day of the week
          end_date = hash_value + 6 > @last_meter_date ? @last_meter_date : hash_value + 6
          start_date = end_date - 6
          period = SchoolDatePeriod.new(:week, 'current week', start_date, end_date)
        else
          raise "Expecting an integer or date as an parameter for a week specification got a #{hash_value.class.name}"
        end
        @periods = [period]
      when :schoolweek
        if hash_value.is_a?(Integer)
          sunday, saturday = @meter_collection.holidays.nth_school_week(@last_meter_date, hash_value)
          period = SchoolDatePeriod.new(:schoolweek, 'current week', sunday, saturday)
          @periods = [period]
        else
          raise EnergySparksBadChartSpecification.new('Expecting integer for :schoolweek timescale configuration')
        end
      when :daterange # used in chart drilldown
        if hash_value.is_a?(Array) && hash_value.length == 2
          period = SchoolDatePeriod.new(:daterange, 'date range', hash_value[0], hash_value[1])
          @periods = [period]
        else
          raise EnergySparksBadChartSpecification.new('Expecting array of 2 dates for :daterange :timescale chart definition')
        end
      when :day
        if hash_value.is_a?(Integer) # hash_value weeks back from latest week
          raise 'Error: expecting zero or negative number for day specification' if hash_value > 0
          start_date = @last_meter_date - hash_value.magnitude
          end_date = start_date
          if start_date < @first_meter_date
            raise "Error: date request for day of data out of range start date #{start_date} before first meter data #{@first_meter_date}"
          else
            period = SchoolDatePeriod.new(:day, 'one day', start_date, end_date)
          end
        elsif hash_value.is_a?(Date) # assume in this case the specified date is the first day of the week
          start_date = hash_value
          end_date = start_date
          period = SchoolDatePeriod.new(:day, 'one day', start_date, end_date)
        else
          raise "Expecting an integer or date as an parameter for a day specification got a #{hash_value.class.name}"
        end
        @periods = [period]
      when :frostday, :frostday_3
        if hash_value.is_a?(Integer) # hash_value weeks back from latest week
          raise EnergySparksBadChartSpecification.new('Error: expecting zero or negative number for frostday specification') if hash_value > 0
          days = @meter_collection.temperatures.frost_days(@first_meter_date, @last_meter_date, 0, @meter_collection.holidays)
          index = hash_value.magnitude
          if index > days.length - 1
            raise EnergySparksBadChartSpecification.new("Not enough frost days #{days.length} for chart specification index #{index}")
          elsif hash_key == :frostday
            period = SchoolDatePeriod.new(:day, 'frost day', days[index], days[index])
          else hash_key == :frostday_3
            start_date = days[index] <= @first_meter_date ? days[index] :  days[index] - 1
            end_date = days[index] >= @last_meter_date ? days[index] :  days[index] + 1
            period = SchoolDatePeriod.new(:day, 'frost day, before and after', start_date, end_date)
          end
        else
          raise EnergySparksBadChartSpecification.new("Expecting an integer or date as an parameter for a day specification got a #{hash_value.class.name}")
        end
        @periods = [period]
      when :diurnal
        if hash_value.is_a?(Integer) # hash_value weeks back from latest week
          raise EnergySparksBadChartSpecification.new('Error: expecting zero or negative number for dirunal range specification') if hash_value > 0
          days = @meter_collection.temperatures.largest_diurnal_ranges(@first_meter_date, @last_meter_date, true, false, @meter_collection.holidays, false)
          index = hash_value.magnitude
          if index > days.length - 1
            raise EnergySparksBadChartSpecification.new("Not enough diurnal range days #{days.length} for chart specification index #{index}")
          else
            period = SchoolDatePeriod.new(:day, 'diurnal day', days[index], days[index])
          end
        else
          raise EnergySparksBadChartSpecification.new("Expecting an integer or date as an parameter for a day specification got a #{hash_value.class.name}")
        end
        @periods = [period]
      else
        raise "Unsupported time period for charting #{@chart_configuration[:timescale]}"
      end
    elsif @chart_configuration[:x_axis] == :year
      @periods = @meter_collection.holidays.years_to_date(@first_meter_date, @last_meter_date, false)
    elsif @chart_configuration[:x_axis] == :academicyear
      @periods = @meter_collection.holidays.academic_years(@first_meter_date, @last_meter_date)
    elsif @chart_configuration[:series_breakdown] == :hotwater
      hotwater_model = calculate_hotwater_model
      period = SchoolDatePeriod.new(nil, 'summer hot water', hotwater_model.analysis_period_start_date, hotwater_model.analysis_period_end_date)
      @periods = [period]
    else
      @periods = [SchoolDatePeriod.new(:chartperiod, 'One Period for Chart', @first_meter_date, @last_meter_date)]
    end
  end

  def calculate_first_chart_date
    @first_chart_date = periods.last.start_date # years in reverse chronological order
  end

  def calculate_last_chart_date
    @last_chart_date = periods.first.end_date # years in reverse chronological order
  end

  def calculate_first_meter_date
    meter_date = Date.new(1995, 1, 1)
    unless @meters[0].nil?
      meter_date = @meters[0].amr_data.start_date
    end
    if !@meters[1].nil? && @meters[1].amr_data.start_date > meter_date
      meter_date = @meters[1].amr_data.start_date
    end
    meter_date
  end

  def calculate_last_meter_date
    meter_date = Date.new(2040, 1, 1)
    unless @meters[0].nil?
      meter_date = @meters[0].amr_data.end_date
    end
    if !@meters[1].nil? && @meters[1].amr_data.end_date < meter_date
      meter_date = @meters[1].amr_data.end_date
    end
    meter_date
  end

  def configure_meters
    if @meter_definition.is_a?(Array)
      meter_type, meter = @meter_definition
    else
      meter_type = @meter_definition
    end

    case meter_type
    when :all
      # treat all meters as being the same, needs to be processed at final stage as kWh addition different from CO2 addition
      meters = [@meter_collection.aggregated_electricity_meters, @meter_collection.aggregated_heat_meters]
    when :allheat
      # aggregate all heat meters
      meters = [nil, @meter_collection.aggregated_heat_meters]
    when :allelectricity
      # aggregate all electricity meters
      meters = [@meter_collection.aggregated_electricity_meters, nil]
    when :electricity_simulator
      meters = [@meter_collection.electricity_simulation_meter, nil]
    end
    @meters = meters
  end
end
