module EnergySparks
  module Maths
    def self.sum(a)
      a.inject(0) { |accum, i| accum + i }
    end

    def self.mean(a)
      sum(a) / a.length.to_f
    end

    def self.sample_variance(a)
      m = mean(a)
      sum = a.inject(0) { |accum, i| accum + (i - m)**2 }
      sum / (a.length - 1).to_f
    end

    def self.standard_deviation(a)
      Math.sqrt(sample_variance(a))
    end
  end
end

# Analyse heating, hot water and kitchen
module AnalyseHeatingAndHotWater
  #====================================================================================================================
  # HOT WATER ANALYSIS
  #
  class HotwaterModel
    attr_reader :buckets, :analysis_period, :efficiency, :analysis_period_start_date
    attr_reader :analysis_period_end_date, :annual_hotwater_kwh_estimate
    attr_reader :avg_school_day_gas_consumption, :avg_holiday_day_gas_consumption, :avg_weekend_day_gas_consumption
    def initialize(meter_collection)
      @meter_collection = meter_collection
      @holidays = @meter_collection.holidays
      @school_day_kwh, @holiday_kwh, @weekend_kwh, @analysis_period, @first_holiday_date = analyse_hotwater_around_summer_holidays(meter_collection.holidays, meter_collection.aggregated_heat_meters)
      @efficiency = (@school_day_kwh - @holiday_kwh) / @school_day_kwh
      @analysis_period_start_date = @analysis_period.start_date
      @analysis_period_end_date = @analysis_period.end_date
      # puts "Analysing hot water system efficiency school day use #{@school_day_kwh} holiday use #{@holiday_kwh} efficiency #{@efficiency}"
      # aggregate_split_day_buckets)archive
    end

    def kwh_daterange(start_date, end_date)
      total_useful_kwh = 0.0
      total_wasted_kwh = 0.0
      (start_date..end_date).each do |date|
        useful_kwh, wasted_kwh = kwh(date)
        total_useful_kwh += useful_kwh
        total_wasted_kwh += wasted_kwh
      end
      [total_useful_kwh, total_wasted_kwh]
    end

    def kwh(date)
      useful_kwh = 0.0
      wasted_kwh = 0.0
      todays_kwh = @meter_collection.aggregated_heat_meters.amr_data.one_day_kwh(date)

      if @holidays.holiday?(date) || DateTimeHelper.weekend?(date)
        wasted_kwh = todays_kwh
      elsif todays_kwh > @holiday_kwh
        wasted_kwh = @holiday_kwh
        useful_kwh = todays_kwh - @holiday_kwh
      else
        wasted_kwh = todays_kwh
      end
      [useful_kwh, wasted_kwh]
    end

    def analyse_hotwater_around_summer_holidays(holidays, meter)
      analysis_period, first_holiday_date = find_period_before_and_during_summer_holidays(holidays, meter.amr_data)

      sum_school_day_gas_consumption = 0.0
      count_school_day_gas_consumption = 0.0

      sum_holiday_weekday_gas_consumption = 0.0
      count_holiday_weekday_gas_consumption = 0.0

      sum_weekend_gas_consumption = 0.0
      count_weekend_gas_consumption = 0.0

      (analysis_period.start_date..analysis_period.end_date).each do |date|
        if date >= first_holiday_date && !DateTimeHelper.weekend?(date)
          sum_holiday_weekday_gas_consumption += meter.amr_data.one_day_kwh(date)
          count_holiday_weekday_gas_consumption += 1.0
        elsif DateTimeHelper.weekend?(date)
          sum_weekend_gas_consumption += meter.amr_data.one_day_kwh(date)
          count_weekend_gas_consumption += 1.0
        else
          sum_school_day_gas_consumption += meter.amr_data.one_day_kwh(date)
          count_school_day_gas_consumption += 1.0
        end
      end
      @avg_school_day_gas_consumption = sum_school_day_gas_consumption / count_school_day_gas_consumption
      @avg_holiday_day_gas_consumption = sum_holiday_weekday_gas_consumption / count_holiday_weekday_gas_consumption
      @avg_weekend_day_gas_consumption = sum_weekend_gas_consumption / count_weekend_gas_consumption

      weeks_holiday = 13
      school_weeks = 52 - 13
      @annual_hotwater_kwh_estimate = avg_school_day_gas_consumption * school_weeks * 5
      @annual_hotwater_kwh_estimate += avg_weekend_day_gas_consumption * school_weeks * 2
      @annual_hotwater_kwh_estimate += avg_holiday_day_gas_consumption * weeks_holiday * 7

      puts "Estimated Annual Hot Water Consumption = #{@annual_hotwater_kwh_estimate.round(0)} kwh"
      puts "Estimated Average School Day HW = #{@avg_school_day_gas_consumption.round(0)} kwh"
      puts "Estimated Average Weekend Day HW = #{@avg_weekend_day_gas_consumption.round(0)} kwh"
      puts "Estimated Average Holiday Day HW = #{@avg_holiday_day_gas_consumption.round(0)} kwh"
      [@avg_school_day_gas_consumption, @avg_holiday_day_gas_consumption, @avg_weekend_day_gas_consumption, analysis_period, first_holiday_date]
    end

    # the analysis relies on having hot water running exclusively before and during the holidays
    # this analysis won't work if these basic conditions aren't met
    def find_period_before_and_during_summer_holidays(holidays, amr_data)
      running_date = amr_data.end_date

      last_summer_hol = holidays.find_summer_holiday_before(running_date)

      [SchoolDatePeriod.new(:date_range, 'Summer Hot Water', last_summer_hol.start_date - 21, last_summer_hol.start_date + 21), last_summer_hol.start_date]
    end
  end

  #====================================================================================================================
  # HEATING MODEL REGRESSION ANALYSIS
  #
  class HeatingModel
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
        puts "Warning: missing dates during regression modelling for #{regression_model_name}"
        # rubocop:disable Naming/VariableNumber
        missing_dates.each_slice(10) do |group_of_10|
          puts group_of_10.to_s
        end
        # rubocop:enable Naming/VariableNumber
      end

      regression(key, regression_model_name, degree_days, days_kwh, degreeday_base_temperature)
    end

    def regression_above_below_limit_currently_unused(period, above, occupied, limit, day_of_week_filter)
      puts "regression_above_below_limit #{period} #{above} #{occupied} #{limit} #{day_of_week_filter}"
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
        puts "Error: empty data set for calculating regression"
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
    attr_reader :models, :heating_on_periods
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
      puts @models.inspect
    end

    # scan through the daily consumption data, using the regression information to determine the heating periods
    # returning a list of the heating periods
    def calculate_heating_periods(start_date, end_date)
      heating_on = false
      heating_start_date = start_date

      puts "Calculating Heating Periods between #{start_date} and #{end_date}"

      (start_date..end_date).each do |date|
        begin
          kwh_today = @amr_data.one_day_kwh(date)
          # degreedays_today = @temperatures.degree_days(date, @base_degreedays_temperature)
          occupied = !DateTimeHelper.weekend?(date) && !@holidays.holiday?(date)

          # degreedays_at_15_5_c = @temperatures.degree_days(date, 15.5)
          @halfway_kwh = @models[:heating_occupied].predicted_kwh_degreedays(0) # degreedays_at_15_5_c)
          @halfway_kwh = 300.0 # TODO(PH,30May2018) - this needs fixing

        # use an average of the predicted heating and non-heated models to attempt to differentiate between
        # heated and non heated days
        #  halfway_kwh =  (@models[:heating_occupied].predicted_kwh_degreedays(degreedays_today) + @models[:nonheating_occupied].predicted_kwh_degreedays(degreedays_today)) / 2.0
        # halfway_kwh = 300.0
          if kwh_today > @halfway_kwh && !heating_on && occupied
            heating_on = true
            heating_start_date = date
          elsif kwh_today <= @halfway_kwh && heating_on && occupied
            heating_on = false
            heating_period = SchoolDatePeriod.new(:heatingperiod, 'N/A', heating_start_date, date)
            @heating_on_periods.push(heating_period)
          end
        rescue StandardError => e
          puts "Unable to calculate heating period for date #{date}", e
        end
      end
      if heating_on
        heating_period = SchoolDatePeriod.new(:heatingperiod, 'N/A', heating_start_date, end_date)
        @heating_on_periods.push(heating_period)
      end
      puts "Heating periods", @heating_on_periods.inspect
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
        @models[:nonheating_occupied].predicted_kwh_degreedaystemperature(temperature)
      end
    end
  end
end
