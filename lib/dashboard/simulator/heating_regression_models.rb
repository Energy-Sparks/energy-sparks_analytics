# Analyse heating, hot water and kitchen
module AnalyseHeatingAndHotWater
  
  #====================================================================================================================
  # HEATING MODEL REGRESSION ANALYSIS
  #
  # this is an abstract base class from which the 'simple' and 'heavy thermal mass' heating models derive
  class HeatingModel
    include Logging

    # holds the basic data for a simple linear regression model:
    # - 'predicted daily kWh heating' = A + B x 'Degree Days'
    # - the year is split into different periods, for which there is a different A + B x DD model fit
    #   - Winter occupied heating: its main use
    #   - Winter holidays and weekends
    #   - Summer non-heating, occupied, weekend and holiday
    # - additionally the heavy thermal mass model splits the winter heating occupied model into 5,
    #   - with a different model for each day of the week
    # - the model needs to be fitted, i.e. real AMR daily kWh data correleated with average daily temperatures
    #   to calculate the A + B x DD regression fit; this is either done on the fly by the validation process
    # - or meter attributes are used to 'guide the process' with human intervention if the automatci fit
    #   is deemed to be poor, this for example may include manually setting the 'balance point temperature'
    #   which is the temperature at which the internal heat gains (humans, electric equipment, sun etc.) offset
    #   the heat losses through the fabric, i.e. the external temperature at which heating is turned on
    #   e.g. 16C external temperature
    # Usages:
    #  - bad data validation: filling in missing gas AMR data, adjusting proxy data for temperature
    #  - estimate of hot water usage from summer sampling, can be used for annual estimates
    #  - alert system: for temperature compensating week on week comparison to alert to increased usage
    #  - fitting process: finding the most accurate model, least CUSUM stdev to support above requirements
    
    # this is the basic model for holding the linerar regression parameters
    class RegressionModel
      attr_reader :key, :long_name, :a, :b, :r2, :base_temperature, :samples

      def initialize(key, long_name, a, b, r2, base_temp, samples)
        @key = key
        @long_name = long_name
        @a = a
        @b = b
        @r2 = r2
        @base_temperature = base_temp
        @samples = samples
      end

      def predicted_kwh_temperature(temperature)
        ddays = [@base_temperature - temperature, 0].max
        predicted_kwh_degreedays(ddays)
      end

      def to_s
        sprintf('kwh=%.0f+%.0dxDD@Tb%.1fC,R2=%.2f', a, b, base_temperature, r2)
      end

      def predicted_kwh_degreedays(degreedays)
        @a + @b * degreedays
      end

      def degreedays(temperature)
        temperature > @base_temperature ? 0.0 : @base_temperature - temperature
      end
    end

    attr_reader :heating_day_determination_method, :heating_determination_value
    attr_reader :models, :heating_on_periods, :heating_days_of_week_parameters
    attr_accessor :base_degreedays_temperature, :halfway_kwh
    attr_accessor :heating_day_determination_method, :heating_day_determination_method_parameter

    def initialize(meter, holidays, temperatures)
      @amr_data = meter.amr_data
      @meter = meter
      @holidays = holidays
      @temperatures = temperatures
      @base_degreedays_temperature = 20.0
      @super_debug = false
      @heating_day_determination_method = :prediction_at_fixed_degreedays
      @heating_determination_value = nil
      process_meter_attributes
    end

    def process_meter_attributes
      model_params = MeterAttributes.attributes(@meter, :heating_model)
      unless model_params.nil?
        model_params.each do |param, value|
          case param
          when :heating_day_determination_method
            process_heating_determination_meter_attributes(model_params[:heating_day_determination_method])
          when :heating_balance_point_temperature
            @base_degreedays_temperature = model_params[:heating_balance_point_temperature].to_f
          when :model
            @model_type = model_params[:model] # the type of model is actual set on construction, not here
          else
            raise EnergySparksUnexpectedStateException.new("Unexpected heating model parameters #{param}")
          end
        end
      end
    end

    def process_heating_determination_meter_attributes(configuraton)
      configuraton.each do |param, value|
        case param
        when :fixed__minimum_per_day
          set_heating_delimination_method(param, value.to_f)
        else
          raise EnergySparksUnexpectedStateException.new("Unexpected heating determination #{param}")
        end
      end
    end

    def set_heating_delimination_method(heating_determination_method, heating_determination_value)
      @heating_determination_method = heating_determination_method
      @heating_determination_value = heating_determination_value
    end

    def cusum_standard_deviation_average
      # puts "Currently configured model: #{self.class.name}"
      results = {}
      results_hash = {
        actual_kwh:    [],
        predicted_kwh: []
      }
      results[:all] = results_hash.deep_dup

      logger.info "Standard deviation calculation between #{@amr_data.start_date}  and #{@amr_data.end_date}"

      (@amr_data.start_date..@amr_data.end_date).each do |date|
        model_type = model_type?(date)
        results[model_type] = results_hash.deep_dup unless results.key?(model_type)

        predicted_kwh = predicted_kwh(date, @temperatures.average_temperature(date))
        actual_kwh = @amr_data.one_day_kwh(date)

        [model_type, :all].each do |type|
          results[type][:actual_kwh].push(actual_kwh) 
          results[type][:predicted_kwh].push(predicted_kwh)
        end
      end

      new_results = results.deep_dup

      results.each do |type, values|
        diffs = [values[:actual_kwh], values[:predicted_kwh]].transpose.map {|x| x.reduce(:-)}
        new_results[type][:standard_deviation] = EnergySparks::Maths.standard_deviation(diffs).round(1).to_f
        new_results[type][:mean] = EnergySparks::Maths.mean(diffs).round(0).to_f
        new_results[type][:samples] = diffs.length
        new_results[type][:total_actual_kwh] = values[:actual_kwh].inject(:+).round(0)
        new_results[type][:total_predicted_kwh] = values[:predicted_kwh].inject(:+).round(0)
        new_results[type].delete(:actual_kwh)
        new_results[type].delete(:predicted_kwh)

        unless type == :all
          new_results[type][:a] = @models[type].a.round(0)
          new_results[type][:b] = @models[type].b.round(0)
          new_results[type][:r2] = @models[type].r2.round(3)
          new_results[type][:t0] = @models[type].base_temperature.round(1)
          new_results[type][:N] = @models[type].samples
          # pseudo aggregate r2 value
          new_results[:all][:r2] = 0.0 unless new_results[:all].key?(:r2) # inside loop for hash order
          new_results[:all][:r2] += @models[type].r2 * new_results[type][:total_actual_kwh]
        end
      end
      new_results[:all][:r2] /= new_results[:all][:total_actual_kwh] # pseudo value
      new_results[:all][:r2] = new_results[:all][:r2].round(4)

      new_results.each do |type, values|
        puts "#{format_cusum_results(type, values)}"
      end
      main = new_results[:all]
      [main[:standard_deviation], main[:mean], main[:total_actual_kwh], main[:total_predicted_kwh], new_results]
    end

    def format_cusum_results(type, results)
      sprintf('%26.26s: sd: %4.0f mean: %3.0f act: %8.0f pred: %8.0f x %4d', type, results[:standard_deviation], 
        results[:mean], results[:total_actual_kwh], results[:total_predicted_kwh], results[:samples])
    end

    def calculate_regression_model(_period)
      raise Not_implemented_error.new('Failed attempt to call calculate_regression_model() on abstract base class of HeatingModel')
    end

    def heating_on?(_date)
      raise Not_implemented_error.new('Failed attempt to call heating_on?() on abstract base class of HeatingModel')
    end

    def predicted_kwh(date, temperature)
      raise Not_implemented_error.new('Failed attempt to call predicted_kwh()heating_on? on abstract base class of HeatingModel')
    end

    def name
      raise Not_implemented_error.new('Failed attempt to call name() on abstract base class of HeatingModel')
    end

    def kwh_saving_for_1_C_thermostat_reduction(start_date, end_date)
      total_kwh = 0.0
      (start_date..end_date).each do |date|
        if heating_on?(date) && !weekend?(date)
          kwh_sensitivity = @models[model_type?(date)].b
          offset = @models[model_type?(date)].a
          # puts "#{date} #{kwh_sensitivity} #{offset} #{base_degreedays_temperature}"
          total_kwh += kwh_sensitivity
        end
      end
      total_kwh
    end

    def save_raw_data_to_csv_for_debug(filename)
      header = ['Date', 'Month', 'DOY', 'Occupied', 'HeatingOn', 'AvgTemp', 'DegreeDays', 'MinHeatkWh',
                'ModelType', 'baseTemp', 'a', 'b', 'TotalkWh', 'PredictedkWh'] + Range.new(0, 47).to_a + Range.new(0, 47).to_a
      File.open(filename, 'w') do |file| 
        file.puts header.join(',')
        (@amr_data.start_date..@amr_data.end_date).each do |date|
          one_days_data = @amr_data[date]
          line = []
          if one_days_data.nil?
            line.push(date)
            line.push('No AMR data for this date')
          else
            avg_temperature = @temperatures.average_temperature(date)
            model_type = model_type?(date)
            degree_days = @temperatures.degree_days(date, base_degreedays_temperature)
            line.push(
              date,
              date.strftime('%m'),
              date.strftime('%a'),
              occupied?(date),
              heating_on?(date),
              avg_temperature,
              degree_days,
              heating_day_minimum_kwh(date, avg_temperature),
              model_type,
              @models[model_type].base_temperature,
              @models[model_type].a,
              @models[model_type].b,
              one_days_data.one_day_kwh,
              predicted_kwh(date, avg_temperature)
            )
            line += one_days_data.kwh_data_x48
            line += @temperatures[date]
          end
          file.puts line.join(',')
        end
      end
    end

    def occupied?(date)
      !weekend?(date) && !holiday?(date)
    end

    def weekend?(date)
      DateTimeHelper.weekend?(date)
    end

    def holiday?(date)
      @holidays.holiday?(date)
    end

    def regression_filtered(key, regression_model_name, occupied, period, list_of_months, heating_on_test, days_of_week, degreeday_base_temperature)
      degree_days = []
      days_kwh = []

      missing_dates = []
      (period.start_date..period.end_date).each do |date|

        # apply 3 tests, in performance order - so structure of code to maximise performance
        if days_of_week.include?(date.wday) && occupied?(date) == occupied
          begin
            if heating_on_off_test(date, list_of_months, heating_on_test)
              kwh_today = @amr_data.one_day_kwh(date)
              if kwh_today != 0.0
                degree_days.push(@temperatures.degree_days(date, degreeday_base_temperature))
                days_kwh.push(kwh_today)
              end
            end
          rescue StandardError => _e
            missing_dates.push(date.strftime('%a%d%b%Y'))
          end
        end
      end

      report_missing_amr_dates(missing_dates) if !missing_dates.empty?

      regression(key, regression_model_name, degree_days, days_kwh, degreeday_base_temperature)
    end

    def report_missing_amr_dates(missing_dates)
      logger.debug 'Warning: missing dates during regression modelling'
      # rubocop:disable Naming/VariableNumber
      missing_dates.each_slice(10) do |group_of_10|
        logger.debug group_of_10.to_s
      end
      # rubocop:enable Naming/VariableNumber
    end

    # if called with list of months, just tests whether within those months
    # else if nil, then bases heating test on calculated min kwh defining heating might be
    # on, or reverse if heating_on_test = false (false for summer/non-heating periods)
    def heating_on_off_test(date, list_of_months, heating_on_test)
      kwh_today = @amr_data.one_day_kwh(date)
      heating_on_off = nil
      if list_of_months.nil?
        temperature = @temperatures.average_temperature(date)
        min_kwh_for_heat_on = heating_day_minimum_kwh(date, temperature)
        heating_on_off = heating_on_test ? (kwh_today >= min_kwh_for_heat_on) : (kwh_today < min_kwh_for_heat_on)
      else
        heating_on_off = list_of_months.include?(date.month)
      end
      heating_on_off
    end

    def regression(key, regression_model_name, x1, y1, degreeday_base_temperature)
      if x1.empty?
        logger.error "Error: empty data set for calculating regression"
        return RegressionModel.new(key, "Error: zero vector", 0.0, 0.0, 0.0, degreeday_base_temperature, 0)
      end
      x = Daru::Vector.new(x1)
      y = Daru::Vector.new(y1)
      sr = Statsample::Regression.simple(x, y)
      model = RegressionModel.new(key, regression_model_name, sr.a, sr.b, sr.r2, degreeday_base_temperature, x1.length)

      if @super_debug
        filename = regression_model_name + ' ' + degreeday_base_temperature.to_s + ' ' + DateTime.now.strftime('%Y%m%d%H%M%3N') + '.csv'
        save_raw_regression_data_to_csv_for_debug(filename, x1, y1, sr.a, sr.b, sr.r2)
      end

      model
    end

    def save_raw_regression_data_to_csv_for_debug(filename, x1, y1, a, b, r2)
      filepath = File.join(File.dirname(__FILE__), '../../../log/' + filename)
      File.open(filepath, 'w') do |file| 
        file.puts "#{a}, #{b}, #{r2}"
        file.puts
        x1.length.times do |i|
          file.puts "#{x1[i]}, #{y1[i]}"
        end
      end
    end
  end

  # the simplest model: same regression for all days of a week when heating on
  class BasicRegressionHeatingModel < HeatingModel
    include Logging

    def initialize(amr_data, holidays, temperatures)
      super(amr_data, holidays, temperatures)
      @models = {}
      @heating_on_periods = []
      @day_to_model_map = {} # [date] = model()
      @heating_days_of_week_parameters = nil
    end

    def name
      'Simple Heating Model'
    end

    def model(type)
      @models[type]
    end

    def configure_models(defined_months)
      @winter_months = defined_months ? [11, 12, 1, 2, 3] : nil
      @summer_months = [5, 6, 7, 8]
      heating_degreeday_base = @base_degreedays_temperature
      summer_degreeday_base = 30
      # different models for different types of days
      # slightly complicated by how a heating day is calculated:
      # - initially by assuming a restricted list of winter months
      # - then using this modelling to more generally apply to shoulder months
      #   based on using the heating consumption to determine whether the heating is on or not...
      @model_config = { # days of week, months, occupied, base temperature, heating on
        heating_occupied_all_days:  [[1, 2, 3, 4, 5], @winter_months, true,   heating_degreeday_base, true],
        winter_weekend:             [[0, 6],          @winter_months, false,  heating_degreeday_base, true],
        winter_holiday:             [[1, 2, 3, 4, 5], @winter_months, false,  heating_degreeday_base, true],
        summer_occupied_all_days:   [[1, 2, 3, 4, 5], @summer_months, true,   summer_degreeday_base, false],
        summer_weekend:             [[0, 6],          @summer_months, false,  summer_degreeday_base, false],
        summer_holiday:             [[1, 2, 3, 4, 5], @summer_months, false,  summer_degreeday_base, false]
      }
    end

    def full_regression_model_calculation(period, temperature = @base_degreedays_temperature,
      delimination_method = @heating_day_determination_method, delimination_parameter = @heating_day_determination_method)

      default_delimination_method = @heating_day_determination_method
      default_delimination_value = delimination_parameter
      begin
        set_heating_delimination_method(delimination_method, delimination_parameter)

        if delimination_method == :fixed__minimum_per_day
          # only need to go through calc cycle once as can already determine a heating day
          calculate_regression_model(period, false)
          calculate_heating_periods(period.start_date, period.end_date)
        else

          # first calculate heating model crudely by assuming heating is on only during fixed winter months
          calculate_regression_model(period, true)
          calculate_heating_periods(period.start_date, period.end_date)
          print_heating_model_results

          # then once the regression model is crudely defined, repeat but for a broader range
          # of dates where the heating period is defined by the daily heating kWh
          # i.e. will include heating periods in shoulder months

          # calculate the regresion again, but using heating periods determined by the previous model calculation
          # rather than fixed winter months
          calculate_regression_model(period, false)
          # then calculate the heating periods again with this more refined regression model
          calculate_heating_periods(period.start_date, period.end_date)
          print_heating_model_results
          sd, mean, actual, predicted = cusum_standard_deviation_average
          logger.info "2: mean #{mean} standard deviation #{sd} actual kwh #{actual} predicted #{predicted}"

          @heating_day_determination_method = :percent_regression_model_prediction
          @heating_day_determination_method_parameter = 0.5
          calculate_heating_periods(period.start_date, period.end_date)
          calculate_regression_model(period, false)

          print_heating_model_results
        end
      rescue StandardError => e
        logger.error 'Error in calculating regression model'
        logger.error e
      end
      # put object/default values back to proginal object settings
      set_heating_delimination_method(default_delimination_method, default_delimination_value)
    end

    def print_heating_model_results
      @models.each do |model_param, results|
        l = sprintf('Results of model calculation (%-26.26s) %5.0f %5.0f %0.3f %4d %3.1f',
                model_param, results.a, results.b, results.r2, results.samples, results.base_temperature)
        logger.info l
      end
    end

    def calculate_regression_model(period, defined_months = true)
      configure_models(defined_months)

      bm = Benchmark.measure {
        @model_config.each do |group_name, config|
          @models[group_name] = regression_filtered(
            :group_name,
            "#{group_name.to_s} DDbaseT=#{config[3]}",
            config[2],  # occupied
            period,
            config[1],  # months
            config[4],  # heating on test
            config[0],  # days of week
            config[3]   # degreeday base
          )
          # puts @models[group_name].inspect
        end
      }
      puts "model calc time #{bm.to_s}"
    end

    def heating_day_minimum_kwh(date, temperature)
      # puts "heating_day_minimum_kwh: #{date} #{temperature} #{@heating_day_determination_method} #{@heating_day_determination_method_parameter}"
      case @heating_day_determination_method
      when :prediction_at_fixed_degreedays
        if @heating_day_determination_method_parameter.nil?
          @models[:heating_occupied_all_days].predicted_kwh_degreedays(0.0)
        else
          @models[:heating_occupied_all_days].predicted_kwh_degreedays(@heating_day_determination_method_parameter)
        end
      when :percent_regression_model_prediction
        @models[:heating_occupied_all_days].predicted_kwh_degreedays(temperature) * @heating_day_determination_method_parameter
      when :zero_heating_only
        if @heating_day_determination_method_parameter.nil?
          0.0 # heating only meter - perhaps too suspectible to noise?
        else
          @heating_day_determination_method_parameter # hard coded kWh/day
        end
      when 'Fixed winter months'
        [11, 12, 1, 2, 3].include?(date.month) ? 0.0 : Float::INFINITY # TODO (PH,22Nov2018) fudge
      else
        raise EnergySparksUnexpectedStateException.new("Unexpected heating day determination method >#{@heating_day_determination_method}<")
      end
    end

    # scan through the daily consumption data, using the regression information
    # to determine the heating periods
    # returning a list of the heating periods
    def calculate_heating_periods(start_date, end_date, log_heating_days = false)
      heating_on = false
      @heating_on_periods = []
      heating_start_date = start_date

      logger.info "Calculating Heating Periods between #{start_date} and #{end_date}"
      previous_date = start_date
      missing_dates = []

      (start_date..end_date).each do |date|
        begin
          if @amr_data.key?(date)
            kwh_today = @amr_data.one_day_kwh(date)
            temperature = @temperatures.average_temperature(date)
            heating_day_min_kwh = heating_day_minimum_kwh(date, temperature)

            if heating_day_min_kwh.nil?
              puts "Ending"
              puts Thread.current.backtrace
              exit
            end

            unless weekend?(date) # skip weekends, i.e. work out heating day ranges for school days and holidays only
              if kwh_today > heating_day_min_kwh && !heating_on
                heating_on = true
                heating_start_date = date
              elsif kwh_today <= heating_day_min_kwh && heating_on
                heating_on = false
                heating_period = SchoolDatePeriod.new(:heatingperiod, 'N/A', heating_start_date, previous_date)
                @heating_on_periods.push(heating_period)
              end
              previous_date = date
            end
          else
            missing_dates.push(date)
          end
        rescue StandardError => e
          logger.error e
        end
      end
      unless missing_dates.empty?
        logger.info "Missing dates during heating period calculation * #{missing_dates.length}:"
        cdprnt = CompactDatePrint.new(missing_dates)
        cdprnt.log
      end
      if heating_on
        heating_period = SchoolDatePeriod.new(:heatingperiod, 'N/A', heating_start_date, end_date)
        @heating_on_periods.push(heating_period)
      end
      if log_heating_days
        logger.debug "Heating periods:"
        SchoolDatePeriod.info_compact(@heating_on_periods)
      end

      logger.info "#{@heating_on_periods.length} heating periods"
      @heating_on_periods
    end

    def heating_on?(date)
      !SchoolDatePeriod.find_period_for_date(date, @heating_on_periods).nil?
    end

    def predicted_kwh(date, temperature)
      @models[model_type?(date)].predicted_kwh_temperature(temperature)
    end

    def model_type?(date)
      if heating_on?(date) && occupied?(date)
        winter_weekday_occupied_model_type?(date)
      elsif [10, 11, 12, 1, 2, 3].include?(date.month)  # winter
        if weekend?(date)
          :winter_weekend
        elsif holiday?(date)
          :winter_holiday
        else
          # logger.info "Unclassified winter daily regression model date #{date}"
          # :heating_occupied_all_days
          winter_weekday_occupied_model_type?(date)
        end
      else # summer
        if occupied?(date)
          :summer_occupied_all_days
        elsif holiday?(date)
          :summer_holiday
        elsif weekend?(date)
          :summer_weekend
        else
          # logger.info "Unclassified summer daily regression model date 2 #{date}"
          :summer_occupied_all_days
        end
      end
    end

    def winter_weekday_occupied_model_type?(_date)
      :heating_occupied_all_days
    end

    def predicted_kwh_daterange(start_date, end_date, temperatures)
      total_kwh = 0.0
      (start_date..end_date).each do |date|
        temperature = temperatures.average_temperature(date)
        total_kwh += predicted_kwh(date, temperature)
      end
      total_kwh
    end

    def predicted_kwh_list_of_dates(list_of_dates, temperatures)
      total_kwh = 0.0
      list_of_dates.each do |date|
        temperature = temperatures.average_temperature(date)
        total_kwh += predicted_kwh(date, temperature)
      end
      total_kwh
    end
  end
#=====================================================================================
# 'heavy thermal mass model' has a different regression model for each day of the week
# - with most (older) schools with high thermal mass and admittance they heat up
#   gradually across the course of a school week (Monday-Friday), a better regression
#   fit and consequent cusum is generated by treating each day seperately
#   however, regressing across all days of the week might be better if limited
#   history is available and the small daily sample size might have a high error term?
#
  class HeatingModelWithThermalMass < BasicRegressionHeatingModel
    def initialize(amr_data, holidays, temperatures)
      super(amr_data, holidays, temperatures)
      @heating_days_of_week_parameters = {
        heating_occupied_monday:    1,
        heating_occupied_tuesday:   2,
        heating_occupied_wednesday: 3,
        heating_occupied_thursday:  4,
        heating_occupied_friday:    5
      }
    end

    def name
      'Thermally Massive Heating Model'
    end

    def configure_models(defined_months = true)
      super(defined_months)

      heating_degreeday_base = @base_degreedays_temperature
      @heating_days_of_week_parameters.each do |day_param, doy_num|
        days_of_week_models = {
          day_param => [[doy_num], @winter_months, true, heating_degreeday_base, true]
        }
        @model_config.merge!(days_of_week_models)
      end
    end

    def winter_weekday_occupied_model_type?(date)
      @heating_days_of_week_parameters.keys[date.wday - 1]
    end
  end
end
