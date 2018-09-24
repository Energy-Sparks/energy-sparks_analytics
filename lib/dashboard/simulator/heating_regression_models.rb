# Analyse heating, hot water and kitchen
module AnalyseHeatingAndHotWater
  
  #====================================================================================================================
  # HEATING MODEL REGRESSION ANALYSIS
  #
  class HeatingModel
    include Logging

    # holds the basic data for a simple linear regression model:
    #   'predicted daily kWh heating' = A + B x 'Degree Days'
    #  - there are variations in derived models which calculate this in a different or more sophisticated way
    #  - depending what fits best for a particular school/building
    class RegressionModel
      attr_reader :key, :long_name, :a, :b, :r2, :base_temperature, :halfway_kwh

      def initialize(key, long_name, a, b, r2, base_temp)
        @key = key
        @long_name = long_name
        @a = a
        @b = b
        @r2 = r2
        @base_temperature = base_temp
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

    def initialize(amr_data, holidays, temperatures)
      @amr_data = amr_data
      @holidays = holidays
      @temperatures = temperatures
    end

    def cusum_standard_deviation_average
      # puts "Currently configured model: #{self.class.name}"
      cusum = []
      (@amr_data.start_date..@amr_data.end_date).each do |date|
        predicted_kwh = predicted_kwh(date, @temperatures.average_temperature(date))
        actual_kwh = @amr_data.one_day_kwh(date)
        cusum.push(actual_kwh - predicted_kwh)
      end
      sd = EnergySparks::Maths.standard_deviation(cusum)
      mean = EnergySparks::Maths.mean(cusum)
      [sd, mean]
    end

    def calculate_regression_model(_period)
      raise Not_implemented_error.new('Failed attempt to call calculate_regression_model on abstract base class of HeatingModel')
    end

    def heating_on?(_date)
      raise Not_implemented_error.new('Failed attempt to call heating_on? on abstract base class of HeatingModel')
    end

    def regression_filtered(key, regression_model_name, occupied, period, list_of_months, list_of_days, degreeday_base_temperature)
      degree_days = []
      days_kwh = []

      missing_dates = []
      (period.start_date..period.end_date).each do |date|
        is_occupied = !DateTimeHelper.weekend?(date) && !@holidays.holiday?(date)
        if occupied == is_occupied && list_of_months.include?(date.month) && list_of_days.include?(date.wday)
          begin
            kwh_today = @amr_data.one_day_kwh(date)
            if kwh_today != 0.0
              degree_days.push(@temperatures.degree_days(date, degreeday_base_temperature))
              days_kwh.push(kwh_today)
            end
          rescue StandardError => _e
            missing_dates.push(date.strftime('%a%d%b%Y'))
          end
        end
      end

      if !missing_dates.empty?
        logger.debug "Warning: missing dates during regression modelling for #{regression_model_name}"
        # rubocop:disable Naming/VariableNumber
        missing_dates.each_slice(10) do |group_of_10|
          logger.debug group_of_10.to_s
        end
        # rubocop:enable Naming/VariableNumber
      end

      regression(key, regression_model_name, degree_days, days_kwh, degreeday_base_temperature)
    end

    def regression_above_below_limit_currently_unused(period, above, occupied, limit, day_of_week_filter)
      logger.debug "regression_above_below_limit #{period} #{above} #{occupied} #{limit} #{day_of_week_filter}"
      degree_days = []
      days_kwh = []

      (period.start_date..period.end_date).each do |date|
        if day_of_week_filter == nil || day_of_week_filter.include?(date.wday)
          is_occupied = !DateTimeHelper.weekend?(date) && !@holidays.holiday?(date)
          if is_occupied == occupied
            kwh_today = @amr_data.one_day_kwh(date)
            degree_day = @temperatures.modified_degree_days(date, 20.0)
            if kwh_today != 0.0
              if (above && kwh_today > limit) || (!above && kwh_today < limit)
                degree_days.push(degree_day)
                days_kwh.push(kwh_today)
              end
            end
          end
        end
      end
      regression(degree_days, days_kwh)
    end

    def regression(key, regression_model_name, x1, y1, degreeday_base_temperature)
      if x1.empty?
        logger.error "Error: empty data set for calculating regression"
        return RegressionModel.new(key, "Error: zero vector", 0.0, 0.0, 0.0, degreeday_base_temperature)
      end
      x = Daru::Vector.new(x1)
      y = Daru::Vector.new(y1)
      sr = Statsample::Regression.simple(x, y)
      RegressionModel.new(key, regression_model_name, sr.a, sr.b, sr.r2, degreeday_base_temperature)
    end
  end

  # the simplest model
  # assumes predicted_kwh = A + B * degreedays for all heating or non heating days (different parameters)
  class BasicRegressionHeatingModel < HeatingModel
    include Logging

    attr_reader :models, :heating_on_periods
    attr_accessor :base_degreedays_temperature

    def initialize(amr_data, holidays, temperatures)
      super(amr_data, holidays, temperatures)
      @base_degreedays_temperature = 20.0
      @models = {}
      @heating_on_periods = []
      @day_to_model_map = {} # [date] = model()
    end

    def model(type)
      @models[type]
    end

    # calculate a basic regression model for the winter (most likely heating months) and summer (most likely unheated months)
    def calculate_regression_model(period)
      # start by basing calc on most likely summer and winter months
      weekdays = [1, 2, 3, 4, 5]
      alldays = [0, 1, 2, 3, 4, 5, 6]
      @models[:heating_occupied] = regression_filtered(:wintermonthsoccupied, 'Heating (occupied)', true, period, [11, 12, 1, 2, 3], weekdays, @base_degreedays_temperature)
      @models[:heating_unoccupied] = regression_filtered(:wintermonthsunoccupied, 'Heating (unoccupied)', false, period, [11, 12, 1, 2, 3], alldays, @base_degreedays_temperature)
      @models[:nonheating_occupied] = regression_filtered(:summermonthsoccupied, 'Un-heated (occupied)', true, period, [6, 7], weekdays, @base_degreedays_temperature)
      @models[:nonheating_unoccupied] = regression_filtered(:summermonthsunoccupied, 'Un-heated (unoccupied)', false, period, [6, 7], alldays, @base_degreedays_temperature)
      logger.debug @models.inspect
    end

    # scan through the daily consumption data, using the regression information to determine the heating periods
    # returning a list of the heating periods
    def calculate_heating_periods(start_date, end_date)
      heating_on = false
      heating_start_date = start_date

      logger.debug "Calculating Heating Periods between #{start_date} and #{end_date}"

      degreedays_at_18c = @base_degreedays_temperature - 18
      degreedays_at_18c = 0.0 if degreedays_at_18c < 0.0
      @halfway_kwh = @models[:heating_occupied].predicted_kwh_degreedays(degreedays_at_18c)

      logger.debug "Setting half way kwh - i.e. split between heating and non heating days to #{@halfway_kwh.round(0)} kWh per day"

      previous_date = start_date
      missing_dates = []
      (start_date..end_date).each do |date|
        begin
          if @amr_data.key?(date)
            kwh_today = @amr_data.one_day_kwh(date)
            # degreedays_today = @temperatures.degree_days(date, @base_degreedays_temperature)
            _occupied = !DateTimeHelper.weekend?(date) && !@holidays.holiday?(date)

            unless DateTimeHelper.weekend?(date) # skip weekends, i.e. workout heating day ranges for school days and holidays only
              if kwh_today > @halfway_kwh && !heating_on
                heating_on = true
                heating_start_date = date
              elsif kwh_today <= @halfway_kwh && heating_on
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
      logger.debug "Heating periods:"
      SchoolDatePeriod.info_compact(@heating_on_periods)

      @heating_on_periods
    end

    def heating_on?(date)
      !SchoolDatePeriod.find_period_for_date(date, @heating_on_periods).nil?
    end

    def predicted_kwh(date, temperature)
      # heating_period = SchoolDatePeriod.find_period_for_date(date, @heating_on_periods)
      if heating_on?(date)
        @models[:heating_occupied].predicted_kwh_temperature(temperature)
      else
        @models[:nonheating_occupied].predicted_kwh_degreedays(temperature)
      end
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

  class HeatingModelWithThermalMass < BasicRegressionHeatingModel
    def intialize(amr_data, holidays, temperatures)
      super(amr_data, holidays, temperatures)
    end

    def calculate_regression_model(period)
      monday = [1]
      weekdays = [2, 3, 4, 5]
      alldays = [0, 1, 2, 3, 4, 5, 6]
      @models[:heating_occupied] = regression_filtered(:wintermonthsoccupied, 'Heating (occupied)', true, period, [11, 12, 1, 2, 3], weekdays, @base_degreedays_temperature)
      @models[:heating_occupied_mon] = regression_filtered(:wintermonthsoccupiedmonday, 'Heating (occupied)', true, period, [11, 12, 1, 2, 3], monday, @base_degreedays_temperature)
      @models[:heating_unoccupied] = regression_filtered(:wintermonthsunoccupied, 'Heating (unoccupied)', false, period, [11, 12, 1, 2, 3], alldays, @base_degreedays_temperature)
      @models[:nonheating_occupied] = regression_filtered(:summermonthsoccupied, 'Un-heated (occupied)', true, period, [6, 7], weekdays, @base_degreedays_temperature)
      @models[:nonheating_unoccupied] = regression_filtered(:summermonthsunoccupied, 'Un-heated (unoccupied)', false, period, [6, 7], alldays, @base_degreedays_temperature)
    end

    def predicted_kwh(date, temperature)
      # heating_period = SchoolDatePeriod.find_period_for_date(date, @heating_on_periods.values)
      if heating_on?(date)
        if date.wday == 1
          @models[:heating_occupied_mon].predicted_kwh_temperature(temperature)
        else
          @models[:heating_occupied].predicted_kwh_temperature(temperature)
        end
      else
        @models[:nonheating_occupied].predicted_kwh_degreedays(temperature)
      end
    end
  end
end
