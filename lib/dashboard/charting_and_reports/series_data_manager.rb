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

  SCHOOLDAYHEATING  = 'Heating On School Days'.freeze
  HOLIDAYHEATING    = 'Heating On Holidays'.freeze
  WEEKENDHEATING    = 'Heating On Weekends'.freeze
  SCHOOLDAYHOTWATER = 'Hot water/kitchen only On School Days'.freeze
  HOLIDAYHOTWATER   = 'Hot water/kitchen only On Holidays'.freeze
  WEEKENDHOTWATER   = 'Hot water/kitchen only On Weekends'.freeze
  BOILEROFF         = 'Boiler Off'.freeze
  HEATINGDAYTYPESERIESNAMES = [SCHOOLDAYHEATING, HOLIDAYHEATING, WEEKENDHEATING, SCHOOLDAYHOTWATER, HOLIDAYHOTWATER, WEEKENDHOTWATER, BOILEROFF].freeze

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
  GRIDCARBON      = 'Carbon Intensity of Electricity Grid (kg/kWh)'.freeze
  GASCARBON       = 'Carbon Intensity of Gas (kg/kWh)'.freeze

  STORAGEHEATERS  = 'storage heaters'
  SOLARPV         = 'solar pv (consumed onsite)'      

  PREDICTEDHEAT   = 'Predicted Heat'.freeze
  CUSUM           = 'CUSUM'.freeze
  BASELOAD        = 'BASELOAD'.freeze
  PEAK_KW         = 'Peak (kW)'.freeze

  USEFULHOTWATERUSAGE = 'Hot Water Usage'.freeze
  WASTEDHOTWATERUSAGE = 'Wasted Hot Water Usage'.freeze
  HOTWATERSERIESNAMES = [USEFULHOTWATERUSAGE, WASTEDHOTWATERUSAGE].freeze

  NONE            = 'Energy'.freeze

  Y2SERIESYMBOLTONAMEMAP = {
    degreedays:   DEGREEDAYS,
    temperature:  TEMPERATURE,
    irradiance:   IRRADIANCE,
    gridcarbon:   GRIDCARBON,
    gascarbon:    GASCARBON
  }.freeze

  def self.y2_axis_key(axis_sym, throw_exception = true)
    if Y2SERIESYMBOLTONAMEMAP.key?(axis_sym)
      Y2SERIESYMBOLTONAMEMAP[axis_sym]
    else
      if throw_exception
        raise EnergySparksBadChartSpecification.new('nil y2 axis specification') if axis_sym.nil?
        raise EnergySparksBadChartSpecification.new("unknown y2 axis specification #{axis_sym}")
      else
        nil
      end
    end
  end

  # plus dynamically generated names, for example meter names
end

class SeriesDataManager
  include Logging
  REMOVE_SOLAR_PV_FROM_FUEL_BREAKDOWN_CHARTS = true # TODO(PH, 26Sep2019) - remove if result satisfactory

  attr_reader :first_meter_date, :last_meter_date, :first_chart_date, :last_chart_date, :periods, :adjust_by_temperature

  def initialize(meter_collection, chart_configuration)
    @meter_collection = meter_collection
    @meter_definition = chart_configuration[:meter_definition]
    @breakdown_list = convert_variable_to_array(chart_configuration[:series_breakdown])
    @y2_axis_list = process_y_axis_config(chart_configuration[:y2_axis])
    @data_types = convert_variable_to_array(chart_configuration[:data_types])
    @heating_model = nil
    @high_thermal_mass_heating_model = nil
    @hotwater_model = nil
    @periods = nil
    @chart_configuration = chart_configuration
    @model_type = chart_configuration.key?(:model) ? chart_configuration[:model] : :best
    configure_manager
    process_temperature_adjustment_config
    logger.info "Series Name Manager: Chart Creation for #{meter_collection}"
  end

  private def override_meter_end_date?
    @chart_configuration.key?(:calendar_picker_allow_up_to_1_week_past_last_meter_date)
  end

  private def process_y_axis_config(y2_axis_config)
    return [] if y2_axis_config.nil? || y2_axis_config == :none
    convert_variable_to_array(y2_axis_config)
  end

  private def process_temperature_adjustment_config
    if @chart_configuration.key?(:adjust_by_temperature)
      @adjust_by_temperature = true
      if @chart_configuration[:adjust_by_temperature].is_a?(Float)
        @adjust_by_temperature_value = @chart_configuration[:adjust_by_temperature]
      elsif @chart_configuration[:adjust_by_temperature].is_a?(Hash)
        @adjust_by_temperature_value = @chart_configuration[:temperature_adjustment_map]
      else
        raise EnergySparksBadChartSpecification, 'Unexpected temperature adjustment type'
      end
    end
    if @chart_configuration.key?(:adjust_by_average_temperature)
      if @chart_configuration[:adjust_by_average_temperature].is_a?(Hash)
        temperatures = adjusted_temperature_values_for_period(@chart_configuration[:adjust_by_average_temperature])
        @adjust_by_average_temperature = temperatures.sum / temperatures.length
        @adjust_by_temperature = true
      else
        raise EnergySparksBadChartSpecification, 'Unexpected average temperature adjustment type'
      end
    end
  end

  private def adjusted_temperature_values_for_period(period_config)
    period_calc = PeriodsBase.period_factory({timescale: period_config}, @meter_collection, @first_meter_date, @last_meter_date)
    period = period_calc.periods[0]
    start_date, end_date = truncate_averaging_range(period)
    (start_date..end_date).to_a.map { |date| @meter_collection.temperatures.average_temperature(date) }
  end

  # allows some fault tolerance in holiday alerts, can be triggered part way through
  # holiday, only need one day of data for averaging temperature to be calculated
  private def truncate_averaging_range(period)
    start_date = [@first_meter_date, period.start_date].max
    end_date   = [@last_meter_date, period.end_date].min
    if end_date - start_date < 0
      dates = "meter #{@first_meter_date} to #{@last_meter_date} and period #{period.start_date} to #{period.end_date}"
      raise EnergySparksNotEnoughDataException, "No overlap for average temperature between #{dates}"
    end
    [start_date, end_date]
  end

  def convert_variable_to_array(value)
    if value.is_a?(Array)
      value
    else
      [value]
    end
  end

  def series_bucket_names
    buckets = []

    [@breakdown_list + @y2_axis_list].flatten.each do |breakdown|
      case breakdown
      when :heating;                buckets = combinatorially_combine(buckets, SeriesNames::HEATINGSERIESNAMES)
      when :heating_daytype;        buckets = combinatorially_combine(buckets, SeriesNames::HEATINGDAYTYPESERIESNAMES)
      when :daytype;                buckets = combinatorially_combine(buckets, SeriesNames::DAYTYPESERIESNAMES)
      when :meter;                  buckets = combinatorially_combine(buckets, meter_names)

      when :model_type;             buckets += heating_model_types
      when :fuel;                   buckets = create_fuel_breakdown
      when :submeter;               buckets += submeter_names
      when :accounting_cost;        buckets += accounting_bill_component_names

      when :hotwater;               buckets += SeriesNames::HOTWATERSERIESNAMES

      when :none;                   buckets.push(SeriesNames::NONE)
      when :cusum;                  buckets.push(SeriesNames::CUSUM)
      when :baseload;               buckets.push(SeriesNames::BASELOAD)
      when :peak_kw;                buckets.push(SeriesNames::PEAK_KW)
      when :predictedheat;          buckets.push(SeriesNames::PREDICTEDHEAT)
      else
        if SeriesNames::Y2SERIESYMBOLTONAMEMAP.key?(breakdown)
          buckets.push(SeriesNames::Y2SERIESYMBOLTONAMEMAP[breakdown])
        else
          # TODO(PH,6Feb2019) - y2 sometimes comes through as nil - not clear why this is happening upstream
          raise EnergySparksBadChartSpecification.new("Unknown series_definition #{breakdown}") unless breakdown.nil?
        end
      end
    end

    @series_buckets = buckets
  end

  def trendlines
    @chart_configuration[:trendlines].map { |series_name| self.class.trendline_for_series_name(series_name) }
  end

  def self.trendline_for_series_name(series_name)
    ('trendline_' + series_name.to_s).to_sym
  end

  def heating_model_types
    heating_model.all_heating_model_types
  end

  def model_series?(series_name)
    heating_model_types.include?(series_name)
  end

  def heating_model_series?(series_name) # duplicate of above>
    heating_model_types.include?(series_name)
  end

  def degreeday_base_temperature
    begin
      return 15.5 # tempeorary fix for unstable models PH 4Jul2019
      base = heating_model.average_base_temperature
      return 30.0 if base > 30.0
      return 10.0 if base < 10.0
      return base
    rescue StandardError => _e
      # TODO(PH, 7Mar2019) - this is a little dangerous as it might give a false
      # impression of the base temperature, the problem lies in the simulator
      # which adds degree days onto the by weekly electricity daytype breakdown
      # chart to provide some indication whether a school has electrical heating
      # the existing call to the modelling infrastructure doesn't work if the
      # school has no gas data, need to resolve as part of the storage heater development?
      20.0
    end
  end

  def self.series_name_for_trendline(trendline_name)
    trendline_name.to_s.sub('trendline_', '' ).to_sym
  end

  def trendlines?
    @chart_configuration.key?(:trendlines)
  end

  def get_data(time_period)
    get_data_private(time_period)
  end

  def submeter_names
    meter = select_one_meter
    submeter_names = []
    meter.sub_meters.values.each do |submeter|
      submeter_names.push(submeter.name)
    end
    submeter_names
  end

  def meter_names
    names = []
    if !@meters[0].nil? # indication of solar pv meters only
      names += @meter_collection.electricity_meters.map(&:display_name)
      # names += @meter_collection.solar_pv_meters.map(&:display_name)
    end
    if !@meters[1].nil? # indication of heat meters only
      names += @meter_collection.heat_meters.map(&:display_name)
      names += @meter_collection.storage_heater_meters.map(&:display_name)
    end
    names
  end

  def accounting_bill_component_names
    names = []
    @meters.each do |meter|
      next if meter.nil?
      meter.amr_data.accounting_tariff.bill_component_types.each do |bill_component_type|
        names.push(bill_component_type) unless names.include?(bill_component_type)
      end
    end
    names
  end

  def get_data_private(time_period)
    timetype, dates, halfhour_index = time_period
    meter = select_one_meter
    breakdown = {}
    case timetype
    when :halfhour, :datetime
      check_requested_meter_date(meter, dates, dates)
      breakdown = getdata_by_halfhour(meter, dates, halfhour_index)
    when :daterange
      check_requested_meter_date(meter, dates[0], dates[1]) unless override_meter_end_date?
      breakdown = getdata_by_daterange(meter, dates[0], dates[1])
    end
    breakdown
  end

  private def check_requested_meter_date(meter, start_date, end_date)
    if start_date < meter.amr_data.start_date || end_date > meter.amr_data.end_date
      requested_dates = start_date == end_date ? "requested data for #{start_date}" : "requested data from #{start_date} to #{end_date}"
      meter_dates = "meter from #{meter.amr_data.start_date} to #{meter.amr_data.end_date}: "
      raise EnergySparksNotEnoughDataException.new("Not enough data for chart aggregation: " + meter_dates + requested_dates)
    end
  end

  def get_one_days_data_x48(date, type = :kwh)
    meter = select_one_meter
    check_requested_meter_date(meter, date, date) # non optimal request
    amr_data_one_day_readings(meter, date, type)
  end

  # implemented for aggregator post aggregaton trend line calculation
  # perhaps should be better integrated into SeriesDataManager getter methods?
  def model_type?(date)
    heating_model.model_type?(date)
  end

  def model(regression_model_type)
    heating_model.model(regression_model_type)
  end

  def getdata_by_halfhour(meter, date, halfhour_index)
    breakdown = {}

    @breakdown_list.each do |breakdown_type|
      case breakdown_type
      when :submeter;         breakdown.merge!(submeter_datetime_breakdown(meter, date, halfhour_index))
      when :meter;            breakdown.merge!(breakdown_to_meter_level(date, date, halfhour_index))
      when :fuel;             breakdown.merge!(fuel_breakdown_halfhour(date, halfhour_index, @meters[0], @meters[1]))
      when :daytype;          breakdown.merge!(daytype_breakdown_halfhour(date, halfhour_index, meter))
      when :accounting_cost;  breakdown.merge!(breakdown_to_bill_components_halfhour(date, halfhour_index, meter))     
      else;                   breakdown[SeriesNames::NONE] = amr_data_by_half_hour(meter, date, halfhour_index, kwh_cost_or_co2)
      end
    end

    @y2_axis_list.each do |breakdown_type|
      case breakdown_type
      when :degreedays;   breakdown[SeriesNames::DEGREEDAYS]  = @meter_collection.temperatures.degree_hour(date, halfhour_index, degreeday_base_temperature)
      when :temperature;  breakdown[SeriesNames::TEMPERATURE] = @meter_collection.temperatures.temperature(date, halfhour_index)
      when :irradiance;   breakdown[SeriesNames::IRRADIANCE]  = @meter_collection.solar_irradiation.solar_irradiance(date, halfhour_index)
      when :gridcarbon;   breakdown[SeriesNames::GRIDCARBON]  = @meter_collection.grid_carbon_intensity.grid_carbon_intensity(date, halfhour_index)
      when :gascarbon;    breakdown[SeriesNames::GASCARBON]   = EnergyEquivalences::UK_GAS_CO2_KG_KWH
      end
    end

    breakdown
  end

  def getdata_by_daterange(meter, d1, d2)
    breakdown = {}
    [@breakdown_list + @y2_axis_list].flatten.each do |breakdown_type|
      case breakdown_type
      when :daytype;          breakdown = daytype_breakdown([d1, d2], meter)
      when :fuel;             breakdown = fuel_breakdown([d1, d2], @meters[0], @meters[1])
      when :heating;          breakdown = heating_breakdown([d1, d2], @meters[0], @meters[1])
      when :heating_daytype;  breakdown = heating_daytype_breakdown([d1, d2], @meters[0], @meters[1])
      when :model_type;       breakdown = heating_model_breakdown([d1, d2], @meters[0], @meters[1])
      when :meter;            breakdown = breakdown_to_meter_level(d1, d2)
      when :accounting_cost;  breakdown = breakdown_to_bill_components_date_range(d1, d2)

      when :hotwater;       breakdown.merge!(hotwater_breakdown(d1, d2))
      when :submeter;       breakdown.merge!(submeter_breakdown(meter, d1, d2))

      when :none;           breakdown[SeriesNames::NONE] = amr_data_date_range(meter, d1, d2, kwh_cost_or_co2)
      when :baseload;       breakdown[SeriesNames::BASELOAD] = meter.amr_data.baseload_kwh_date_range(d1, d2)
      when :peak_kw;        breakdown[SeriesNames::PEAK_KW] = meter.amr_data.peak_kw_kwh_date_range(d1, d2)
      when :cusum;          breakdown[SeriesNames::CUSUM] = cusum(meter, d1, d2)
      when :degreedays;     breakdown[SeriesNames::DEGREEDAYS] = @meter_collection.temperatures.degrees_days_average_in_range(degreeday_base_temperature, d1, d2)
      when :temperature;    breakdown[SeriesNames::TEMPERATURE] = @meter_collection.temperatures.average_temperature_in_date_range(d1, d2)
      when :irradiance;     breakdown[SeriesNames::IRRADIANCE] = @meter_collection.solar_irradiation.average_daytime_irradiance_in_date_range(d1, d2)
      when :gridcarbon;     breakdown[SeriesNames::GRIDCARBON] = @meter_collection.grid_carbon_intensity.average_in_date_range(d1, d2)
      when :gascarbon;      breakdown[SeriesNames::GASCARBON]   = EnergyEquivalences::UK_GAS_CO2_KG_KWH
      when :predictedheat;  breakdown[SeriesNames::PREDICTEDHEAT] = heating_model.predicted_kwh_daterange(d1, d2, @meter_collection.temperatures)
      end
    end
    breakdown
  end

  def amr_data_by_half_hour(meter, date, halfhour_index, data_type = :kwh)
    meter.amr_data.kwh(date, halfhour_index, data_type)
  end

  def amr_data_one_day_readings(meter, date, data_type = :kwh)
    meter.amr_data.days_kwh_x48(date, data_type)
  end

  def amr_data_one_day(meter, date, data_type = :kwh) 
    meter.amr_data.one_day_kwh(date, data_type)
  end

  def predicted_amr_data_one_day(date)
    heating_model.predicted_kwh(date, @meter_collection.temperatures.average_temperature(date))
  end

  private def scaling_factor_for_model_derived_gas_data(data_type)
    case data_type
    when :£, :economic_cost;      BenchmarkMetrics::GAS_PRICE
    when :accounting_cost;        BenchmarkMetrics::GAS_PRICE # TODO(PH, 7Apr2019) - not correct, need to look up accounting tariff on day
    when :co2;                    EnergyEquivalences::UK_GAS_CO2_KG_KWH
    else;                         1.0 end
  end

  def amr_data_date_range(meter, start_date, end_date, data_type)
    if @adjust_by_temperature && meter.fuel_type == :gas
      scale = scaling_factor_for_model_derived_gas_data(data_type)
      if @adjust_by_temperature_value.is_a?(Float)
        scale * heating_model.temperature_compensated_date_range_gas_kwh(start_date, end_date, @adjust_by_temperature_value, 0.0)
      elsif !@adjust_by_average_temperature.nil?
        scale * heating_model.temperature_compensated_date_range_gas_kwh(start_date, end_date, @adjust_by_average_temperature, 0.0)
      elsif @adjust_by_temperature_value.is_a?(Hash)
        # see aggregator.temperature_compensation_temperature_map comments for more detailed explanation
        # but adjusts gas data to corresponding temperatures of first series
        total_adjusted_kwh = 0.0
        (start_date..end_date).each do |date|
          total_adjusted_kwh += heating_model.temperature_compensated_one_day_gas_kwh(date, @adjust_by_temperature_value[date])
        end
        [scale * total_adjusted_kwh, 0.0].max
      else
        raise EnergySparksUnexpectedStateException, "Expecting Float or Hash for @adjust_by_temperature_value when @adjust_by_temperature true: #{@adjust_by_temperature_value}"
      end
    elsif override_meter_end_date?
      total = 0.0
      (start_date..end_date).each do |date|
        total += date > meter.amr_data.end_date ? 0.0 : meter.amr_data.one_day_kwh(date, data_type)
      end
      total
    else
      meter.amr_data.kwh_date_range(start_date, end_date, data_type)
    end
  end

  def daily_high_thermal_mass_heating_model
    @high_thermal_mass_heating_model = calculate_high_thermal_mass_model if @high_thermal_mass_heating_model.nil?
  end

  def heating_model
    @heating_model = calculate_model if @heating_model.nil?
    @heating_model
  end

  def kwh_cost_or_co2
    case @chart_configuration[:yaxis_units]
    when :£;               :economic_cost
    when :accounting_cost; :accounting_cost
    when :co2;             :co2
    else;                  :kwh end
  end

  def trendline_scale
    scaling_factor_for_model_derived_gas_data(kwh_cost_or_co2)
  end

private

  def create_fuel_breakdown
    buckets = ['electricity', 'gas']
    buckets.push(SeriesNames::STORAGEHEATERS) if @meter_collection.storage_heaters?
    buckets.push(SeriesNames::SOLARPV) if @meter_collection.solar_pv_panels? && !REMOVE_SOLAR_PV_FROM_FUEL_BREAKDOWN_CHARTS
    buckets
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
    calculate_model_by_type(@model_type)
  end

  def calculate_high_thermal_mass_model
    @high_thermal_mass_heating_model = calculate_model_by_type(:thermal_mass_regression_temperature)
  end

  def calculate_model_by_type(model_type)
    # model calculated using the latest year's regression data,deliberately ignores chart request
    last_year = SchoolDatePeriod.year_to_date(:year_to_date, 'validate amr', @last_meter_date, @first_meter_date)
    meter = select_one_meter([:gas, :storage_heater])
    logger.info "Calculating heating model for #{meter.id} - SeriesDataManager::calculate_model_by_type"
    meter.heating_model(last_year, model_type)
  end

  def calculate_hotwater_model
    @hotwater_model = AnalyseHeatingAndHotWater::HotwaterModel.new(@meter_collection) if @hotwater_model.nil?
    @hotwater_model
  end

   # TODO(PH,22May2018) meter selection needs revisiting
  def select_one_meter(preferred_fuel_types = nil)
    if @meters[0].nil?
      @meters[1]
    elsif !preferred_fuel_types.nil?
      if !@meters[0].nil? &&  [preferred_fuel_types].flatten.include?(@meters[0].fuel_type)
        @meters[0]
      else
        @meters[1]
      end
    else
      @meters[0]
    end
  end

  def daytype_breakdown(date_range, meter)
    data_type = kwh_cost_or_co2

    daytype_data = {
      SeriesNames::HOLIDAY => 0.0,
      SeriesNames::WEEKEND => 0.0,
      SeriesNames::SCHOOLDAYOPEN => 0.0,
      SeriesNames::SCHOOLDAYCLOSED => 0.0
    }
    (date_range[0]..date_range[1]).each do |date|
      begin
        if @meter_collection.holidays.holiday?(date)
          daytype_data[SeriesNames::HOLIDAY] += amr_data_one_day(meter, date, data_type)
        elsif DateTimeHelper.weekend?(date)
          daytype_data[SeriesNames::WEEKEND] += amr_data_one_day(meter, date, data_type)
        else
          open_kwh, close_kwh = intraday_breakdown(meter, date, data_type)
          daytype_data[SeriesNames::SCHOOLDAYOPEN] += open_kwh
          daytype_data[SeriesNames::SCHOOLDAYCLOSED] += close_kwh
        end
      rescue StandardError => e
        logger.error "Unable to aggregate data for #{date} - exception raise"
        raise e
      end
    end
    daytype_data
  end

  def close_to(v1, v2, max_diff)
    if v1 == 0 && v2 == 0
      return true
    else
      return ((v1 - v2) / v1) < max_diff
    end
  end

  # for speed aggregate single day breakdown using ranges
  # does fractional calculation if open/close time not on 30 minute boundary (TODO (PH, 6Feb2019) currently untested)
  def intraday_breakdown(meter, date, data_type)
    if @cached_weighted_open_x48.nil?
      # fudge: override start time if storage heater: TODO(PH, 30Oct2019) move to specialised Meter class
      # start_time = meter.meter_type == :storage_heater ? TimeOfDay.new(0, 0) : @meter_collection.open_time
      start_time = @meter_collection.open_time
      open_time = start_time..@meter_collection.close_time
      @cached_weighted_open_x48 = DateTimeHelper.weighted_x48_vector_multiple_ranges([open_time])
    end
    one_day_readings = amr_data_one_day_readings(meter, date, data_type)
    open_kwh_x48 = AMRData.fast_multiply_x48_x_x48(one_day_readings, @cached_weighted_open_x48)
    open_kwh =  open_kwh_x48.sum
    close_kwh = amr_data_one_day(meter, date, data_type) - open_kwh
    [open_kwh, close_kwh]
  end

  def daytype_breakdown_halfhour(date, halfhour_index, meter)
    val = amr_data_by_half_hour(meter, date, halfhour_index, kwh_cost_or_co2)

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
      time_of_day = DateTimeHelper.time_of_day(halfhour_index)
      daytype_type = @meter_collection.is_school_usually_open?(date, time_of_day) ? SeriesNames::SCHOOLDAYOPEN : SeriesNames::SCHOOLDAYCLOSED
      daytype_data[daytype_type] = val
    end

    daytype_data
  end

  private def breakdown_to_bill_components_halfhour(date, halfhour_index, meter)
    meter.amr_data.accounting_tariff.cost_data_halfhour_broken_down(date, halfhour_index)
  end

  def cusum(meter, date1, date2)
    scale = scaling_factor_for_model_derived_gas_data(kwh_cost_or_co2)
    model_kwh = heating_model.predicted_kwh_daterange(date1, date2, @meter_collection.temperatures)
    actual_kwh = amr_data_date_range(meter, date1, date2, :kwh)
    (model_kwh - actual_kwh) * scale
  end

  def hotwater_breakdown(date1, date2)
    breakdown = {}
    scale = scaling_factor_for_model_derived_gas_data(kwh_cost_or_co2)
    hotwater_model = calculate_hotwater_model
    useful_kwh, wasted_kwh = hotwater_model.kwh_daterange(date1, date2)
    breakdown[SeriesNames::USEFULHOTWATERUSAGE] = useful_kwh * scale
    breakdown[SeriesNames::WASTEDHOTWATERUSAGE] = wasted_kwh * scale
    breakdown
  end

  def submeter_datetime_breakdown(meter, date, halfhour_index)
    breakdown = {}
    meter.sub_meters.values.each do |submeter|
      breakdown[submeter.name] = amr_data_by_half_hour(submeter, date, halfhour_index, kwh_cost_or_co2)
    end
    breakdown
  end

  def submeter_breakdown(meter, date1, date2)
    breakdown = {}
    meter.sub_meters.values.each do |submeter|
      breakdown[submeter.name] = amr_data_date_range(submeter, date1, date2, kwh_cost_or_co2)
    end
    breakdown
  end

  def breakdown_to_meter_level(start_date, end_date, halfhour_index = nil)
    breakdown = {}
    meter_names.each do |meter_name|
      breakdown[meter_name] = 0.0
    end
    unless @meters[0].nil? # indication of electricity only
      breakdown = merge_breakdown(breakdown, breakdown_one_meter_type(@meter_collection.aggregated_electricity_meters, @meter_collection.electricity_meters, start_date, end_date, halfhour_index))
      # breakdown = merge_breakdown(breakdown, breakdown_one_meter_type(@meter_collection.aggregated_electricity_meters.sub_meters[:generation], @meter_collection.solar_pv_meters, start_date, end_date, halfhour_index))
    end
    unless @meters[1].nil? # indication of heat meters only
      breakdown = merge_breakdown(breakdown, breakdown_one_meter_type(@meter_collection.aggregated_heat_meters, @meter_collection.heat_meters, start_date, end_date, halfhour_index))
      breakdown = merge_breakdown(breakdown, breakdown_one_meter_type(@meter_collection.storage_heater_meter, @meter_collection.storage_heater_meters, start_date, end_date, halfhour_index))
    end
    breakdown
  end

  private def breakdown_to_bill_components_date_range(start_date, end_date)
    bill_components = Hash.new(0.0)
    @meters.each do |meter|
      next if meter.nil?
      (start_date..end_date).each do |date|
        components = meter.amr_data.accounting_tariff.bill_component_costs_for_day(date)
        components.each do |type, value|
          bill_components[type] += value
        end
      end
    end
    bill_components
  end

  def breakdown_one_meter_type(aggregate_meter, list_of_meters, start_date, end_date, halfhour_index = nil)
    breakdown = {}
    unless list_of_meters.nil?
      list_of_meters.each do |meter|
        begin
          if halfhour_index.nil?
            start_date, end_date, ok = truncate_date_range_to_aggregate(aggregate_meter, start_date, end_date)
            breakdown[meter.display_name] = ok ? amr_data_date_range(meter, start_date, end_date, kwh_cost_or_co2) : 0.0
          else
            breakdown[meter.display_name] = 0.0
            (start_date..end_date).each do |date|
              ok = within_aggregate_date_range?(aggregate_meter, date)
              breakdown[meter.display_name] = set_zero(amr_data_by_half_hour(meter, date, halfhour_index, kwh_cost_or_co2), !ok)
            end
          end
        rescue Exception => e
          logger.error "Failure getting meter breakdown data for #{meter.display_name} between #{start_date} and #{end_date}"
          logger.error e
        end
      end
    end
    breakdown
  end

  def set_zero(value, set_zero)
    set_zero ? 0.0 : value
  end

  def within_aggregate_date_range?(aggregate_meter, date)
    return true if aggregate_meter.nil?
    date.between?(aggregate_meter.amr_date.start_date, aggregate_meter.amr_date.end_date)
  end

  def truncate_date_range_to_aggregate(aggregate_meter, start_date, end_date)
    start_date = [start_date, aggregate_meter.amr_data.start_date].max
    end_date   = [end_date,   aggregate_meter.amr_data.end_date  ].min
    [start_date, end_date, start_date <= end_date]
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
    has_storage_heaters = @meter_collection.storage_heaters?
    has_solar_pv_panels = @meter_collection.solar_pv_panels?
    fuel_data = {
      'electricity' => 0.0,
      'gas' => 0.0
    }
    fuel_data[SeriesNames::STORAGEHEATERS] = 0.0 if has_storage_heaters
    fuel_data[SeriesNames::SOLARPV] = 0.0 if has_solar_pv_panels && !REMOVE_SOLAR_PV_FROM_FUEL_BREAKDOWN_CHARTS

    (date_range[0]..date_range[1]).each do |date|
      begin
        if gas_meter.nil?
          fuel_data['gas'] += 0.0
        else
          fuel_data['gas'] += amr_data_one_day(gas_meter, date, kwh_cost_or_co2)
        end
        if electricity_meter.nil?
          fuel_data['electricity'] += 0.0
        else
          fuel_data['electricity'] += amr_data_one_day(electricity_meter, date, kwh_cost_or_co2)
        end
        fuel_data[SeriesNames::STORAGEHEATERS] += @meter_collection.storage_heater_meter.amr_data.one_day_kwh(date, kwh_cost_or_co2) if has_storage_heaters
        fuel_data[SeriesNames::SOLARPV] += -1.0 * @meter_collection.solar_pv_meter.amr_data.one_day_kwh(date, kwh_cost_or_co2) if has_solar_pv_panels && !REMOVE_SOLAR_PV_FROM_FUEL_BREAKDOWN_CHARTS
      rescue Exception => e
        logger.error "Missing or nil data on #{date}"
        logger.error e
      end
    end
    fuel_data
  end

  def fuel_breakdown_halfhour(date, halfhour_index, electricity_meter, gas_meter)
    electric_val = electricity_meter.nil? ? 0.0 : amr_data_by_half_hour(electricity_meter, date, halfhour_index, kwh_cost_or_co2)
    gas_val = gas_meter.nil? ? 0.0 : amr_data_by_half_hour(gas_meter, date, halfhour_index, kwh_cost_or_co2)

    fuel_data = {
      'electricity' => electric_val,
      'gas' => gas_val
    }

    fuel_data[SeriesNames::STORAGEHEATERS] = @meter_collection.storage_heater_meter.amr_data.kwh(date, halfhour_index, kwh_cost_or_co2) if @meter_collection.storage_heaters?
    fuel_data[SeriesNames::SOLARPV] += -1.0 * @meter_collection.solar_pv_meter.amr_data.kwh(date, halfhour_index, kwh_cost_or_co2) if @meter_collection.solar_pv_panels? && !REMOVE_SOLAR_PV_FROM_FUEL_BREAKDOWN_CHARTS
    fuel_data
  end

  def heating_breakdown(date_range, electricity_meter, heat_meter)
    meter = (!electricity_meter.nil? && electricity_meter.storage_heater?) ? electricity_meter : heat_meter
    heating_data = { SeriesNames::HEATINGDAY => 0.0, SeriesNames::NONHEATINGDAY => 0.0 }
    (date_range[0]..date_range[1]).each do |date|
      begin
        type = heating_model.heating_on?(date) ? SeriesNames::HEATINGDAY : SeriesNames::NONHEATINGDAY
        heating_data[type] += amr_data_one_day(meter, date, kwh_cost_or_co2)
      rescue StandardError => e
        logger.error e
        logger.error "Warning: unable to calculate heating breakdown on #{date}"
      end
    end
    heating_data
  end

  def heating_daytype_breakdown(date_range, electricity_meter, heat_meter)
    meter = (!electricity_meter.nil? && electricity_meter.storage_heater?) ? electricity_meter : heat_meter
    heating_data = SeriesNames::HEATINGDAYTYPESERIESNAMES.map { |heating_daytype| [heating_daytype, 0.0] }.to_h
    (date_range[0]..date_range[1]).each do |date|
      begin
        type = convert_model_name_to_heating_daytype(date)
        one_day_value = amr_data_one_day(meter, date, kwh_cost_or_co2)
        # this is a fudge, to avoid restructuring of aggregation/series data manager interface
        # based back to allow count to work for adding 'XXX days' to legend
        # the modelling of 'BOILEROFF' allows days with small kWh, assuming its meter noise
        one_day_value = Float::MIN if one_day_value == 0.0 && type == SeriesNames::BOILEROFF
        heating_data[type] += one_day_value
      rescue StandardError => e
        logger.error e
        logger.error "Warning: unable to calculate heating breakdown on #{date}"
      end
    end
    heating_data
  end

  public def convert_model_name_to_heating_daytype(date)
    # use daytype logic here, rather than switching on model types
    # which have also had daytype logic applied to them
    # small risk of inconsistancy, but reduces dependancy between
    # this code and the regression models
    return SeriesNames::BOILEROFF if heating_model.boiler_off?(date)

    heating_on = heating_model.heating_on?(date)
    if @meter_collection.holidays.holiday?(date)
      heating_on ? SeriesNames::HOLIDAYHEATING : SeriesNames::HOLIDAYHOTWATER
    elsif DateTimeHelper.weekend?(date)
      heating_on ? SeriesNames::WEEKENDHEATING : SeriesNames::WEEKENDHOTWATER
    else
      heating_on ? SeriesNames::SCHOOLDAYHEATING : SeriesNames::SCHOOLDAYHOTWATER
    end
  end

  # this breakdown uses NaN to indicate missing data, so Excel doesn't plot it
  def heating_model_breakdown(date_range, electricity_meter, heat_meter)
    # puts "non heat meter #{electricity_meter} #{electricity_meter.storage_heater?}"
    meter = (!electricity_meter.nil? && electricity_meter.storage_heater?) ? electricity_meter : heat_meter
    breakdown = {}
    regression_regimes = heating_model_types
    regression_regimes.each do |regime|
      breakdown[regime] = Float::NAN
    end

    (date_range[0]..date_range[1]).each do |date|
      begin
        type = heating_model.model_type?(date)
        if breakdown[type].nil? || breakdown[type].nan?
          breakdown[type] = amr_data_one_day(meter, date, kwh_cost_or_co2)
        else
          breakdown[type] += amr_data_one_day(meter, date, kwh_cost_or_co2)
        end
      rescue StandardError => e
        logger.error e
        logger.error "Warning: unable to calculate heating model type breakdown on #{date}"
      end
    end
    breakdown
  end

  def predicted_heating_breakdown(date_range, _electricity_meter, heat_meter)
    heating_data = { SeriesNames::HEATINGDAYMODEL => 0.0, SeriesNames::NONHEATINGDAYMODEL => 0.0 }
    (date_range[0]..date_range[1]).each do |date|
      begin
        type = heating_model.heating_on?(date) ? SeriesNames::HEATINGDAYMODEL : SeriesNames::NONHEATINGDAYMODEL
        avg_temp = @meter_collection.temperatures.average_temperature(date)
        heating_data[type] += heating_model.predicted_kwh(date, avg_temp, kwh_cost_or_co2)
      rescue StandardError => e
        logger.error "Missing or nil predicted heating data on #{date}"
        logger.error e
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

  def calculate_periods
    period_calc = PeriodsBase.period_factory(@chart_configuration, @meter_collection, @first_meter_date, @last_meter_date)
    @periods = period_calc.periods
  end

  def calculate_first_chart_date
    nil_period_count = periods.count(&:nil?)
    raise EnergySparksNotEnoughDataException, "Not enough data for chart (nil period x#{nil_period_count})" if nil_period_count > 0 || periods.length == 0
    @first_chart_date = periods.last.start_date # years in reverse chronological order
  end

  def calculate_last_chart_date
    @last_chart_date = periods.first.end_date # years in reverse chronological order
  end

  def y2_axis_uses_temperatures
    @chart_configuration.key?(:y2_axis) && (@chart_configuration[:y2_axis] == :degreedays ||  @chart_configuration[:y2_axis] == :temperature)
  end

  def y2_axis_uses_solar_irradiance?
    @chart_configuration.key?(:y2_axis) && @chart_configuration[:y2_axis] == :irradiance
  end

  def calculate_first_meter_date
    meter_date = Date.new(1995, 1, 1)
    unless @meters[0].nil?
      meter_date = @meters[0].amr_data.start_date
    end
    if !@meters[1].nil? && @meters[1].amr_data.start_date > meter_date
      meter_date = @meters[1].amr_data.start_date
    end
    if y2_axis_uses_temperatures && @meter_collection.temperatures.start_date > meter_date
      logger.info "Reducing meter range because temperature axis with less data on chart #{meter_date} versus #{@meter_collection.temperatures.start_date}"
      meter_date = @meter_collection.temperatures.start_date # this may not be strict enough?
    end
    if y2_axis_uses_solar_irradiance? && @meter_collection.solar_irradiation.start_date > meter_date
      logger.info "Reducing meter range because irradiance axis with less data on chart #{meter_date} versus #{@meter_collection.solar_irradiation.start_date}"
      meter_date = @meter_collection.solar_irradiation.start_date
    end
    meter_date = @chart_configuration[:min_combined_school_date] if @chart_configuration.key?(:min_combined_school_date)
    meter_date
  end

  def calculate_last_meter_date
    meter_date = [Date.new(2040, 1, 1), @meters.compact.map { |meter| meter.amr_data.end_date }].flatten.min
    if y2_axis_uses_temperatures && @meter_collection.temperatures.end_date < meter_date
      logger.info "Reducing meter range because temperature axis with less data on chart #{meter_date} versus #{@meter_collection.temperatures.end_date}"
      meter_date = @meter_collection.temperatures.end_date # this may not be strict enough?
    end
    if y2_axis_uses_solar_irradiance? && @meter_collection.solar_irradiation.end_date < meter_date
      logger.info "Reducing meter range because irradiance axis with less data on chart #{meter_date} versus #{@meter_collection.solar_irradiation.end_date}"
      meter_date = @meter_collection.solar_irradiation.end_date # this may not be strict enough?
    end
    meter_date = @chart_configuration[:max_combined_school_date] if @chart_configuration.key?(:max_combined_school_date)
    meter_date = @chart_configuration[:asof_date] if @chart_configuration.key?(:asof_date)
    meter_date
  end

  def configure_meters
    logger.info "Configuring meter #{@meter_definition}"
    # typically meter[0] is an electricity meter (electricity, solar_pv), and meter[1] is a heating meter (gas, storage)
    if @meter_definition.is_a?(Symbol)
      case @meter_definition
      when :all
        # treat all meters as being the same, needs to be processed at final stage as kWh addition different from CO2 addition
        @meters = [@meter_collection.aggregated_electricity_meters, @meter_collection.aggregated_heat_meters]
      when :allheat
        # aggregate all heat meters
        @meters = [nil, @meter_collection.aggregated_heat_meters]
      when :allelectricity
        # aggregate all electricity meters
        @meters = [@meter_collection.aggregated_electricity_meters, nil]
      when :allelectricity_unmodified
        @meters = [unmodified_aggregated_electricity_meter, nil]
      when :electricity_simulator
        @meters = [@meter_collection.electricity_simulation_meter, nil]
      when :storage_heater_meter
        @meters = [@meter_collection.storage_heater_meter, nil]
      when :solar_pv_meter, :solar_pv
        @meters = [@meter_collection.aggregated_electricity_meters.sub_meters[:generation], nil]
      end
    elsif @meter_definition.is_a?(String) || @meter_definition.is_a?(Integer)
      # specified meter - typically by mpan or mprn
      meter = @meter_collection.meter?(@meter_definition)
      @meters = meter.heat_meter? ? [nil, meter] : [meter, nil]
    end
  end

  def unmodified_aggregated_electricity_meter
    if @meter_collection.aggregated_electricity_meters.sub_meters.key?(:mains_consume)
      @meter_collection.aggregated_electricity_meters.sub_meters[:mains_consume]
    else
      @meter_collection.aggregated_electricity_meters
    end
  end
end
