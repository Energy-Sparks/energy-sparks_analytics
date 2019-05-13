# Analyse heating, hot water and kitchen
module AnalyseHeatingAndHotWater
  #====================================================================================================================
  # HOT WATER ANALYSIS
  #
  class HotwaterModel
    include Logging

    HEATCAPACITYWATER = 4.2 # J/g/K
    PUPILUSAGELITRES = 5
    HWTEMPERATURE = 35 # C
    BATHLITRES = 60
    SEASONALBOILEREFFICIENCY = 0.65
    # https://cms.esi.info/Media/documents/Stieb_SNU_ML.pdf
    STANDING_LOSS_FROM_ELECTRIC_WATER_HEATER_KWH_PER_DAY = 0.25
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
      # logger.debug "Analysing hot water system efficiency school day use #{@school_day_kwh} holiday use #{@holiday_kwh} efficiency #{@efficiency}"
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

    def overall_efficiency
      efficiency * SEASONALBOILEREFFICIENCY
    end

    def self.benchmark_one_day_pupil_kwh
      HEATCAPACITYWATER * PUPILUSAGELITRES * (HWTEMPERATURE - 10) * 1_000.0 / 3_600_000.0
    end

    def self.annual_point_of_use_electricity_meter_kwh(pupils)
      number_heaters = (pupils / 30.0).ceil
      standing_loss = number_heaters * STANDING_LOSS_FROM_ELECTRIC_WATER_HEATER_KWH_PER_DAY * 365
      hot_water_usage = benchmark_annual_pupil_kwh * pupils
      [hot_water_usage, standing_loss, hot_water_usage + standing_loss]
    end

    def self.litres_of_hotwater(kwh)
      ((kwh * 3_600_000.0)/(HEATCAPACITYWATER * 1_000.0 * (HWTEMPERATURE - 10))).round(1)
    end

    def self.baths_of_hotwater(kwh)
      self.litres_of_hotwater(kwh).round(1) / BATHLITRES
    end

    def self.benchmark_annual_pupil_kwh
      39 * 5 * benchmark_one_day_pupil_kwh
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

      logger.debug "Estimated Annual Hot Water Consumption = #{@annual_hotwater_kwh_estimate.round(0)} kwh"
      logger.debug "Estimated Average School Day HW = #{@avg_school_day_gas_consumption.round(0)} kwh"
      logger.debug "Estimated Average Weekend Day HW = #{@avg_weekend_day_gas_consumption.round(0)} kwh"
      logger.debug "Estimated Average Holiday Day HW = #{@avg_holiday_day_gas_consumption.round(0)} kwh"
      [@avg_school_day_gas_consumption, @avg_holiday_day_gas_consumption, @avg_weekend_day_gas_consumption, analysis_period, first_holiday_date]
    end

    # the analysis relies on having hot water running exclusively before and during the holidays
    # this analysis won't work if these basic conditions aren't met
    def find_period_before_and_during_summer_holidays(holidays, amr_data)
      running_date = amr_data.end_date

      last_summer_hol = holidays.find_summer_holiday_before(running_date)

      return nil if last_summer_hol.nil?

      [SchoolDatePeriod.new(:date_range, 'Summer Hot Water', last_summer_hol.start_date - 21, last_summer_hol.start_date + 21), last_summer_hol.start_date]
    end
  end
end
