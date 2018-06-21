
# validates AMR data
# - checks for missing data
#   - if there is too big a gap it reduces the start and end dates for the amr data
#   - if there are smaller gaps it attempts to fill them in using nearby data
#   - and if its heat/gas data then it adjusts for temperature
class ValidateAMRData
  FSTRDEF = '%a %d %b %Y'.freeze # fixed format for reporting dates for error messages
  MAXGASAVGTEMPDIFF = 5 # max average temperature difference over which to adjust temperatures
  attr_reader :data_problems
  def initialize(meter, max_days_missing_data, holidays, temperatures)
    @amr_data = meter.amr_data
    @meter = meter
    @type = meter.meter_type
    @holidays = holidays
    @temperatures = temperatures
    @heating_model = nil
    @max_days_missing_data = max_days_missing_data
    @max_search_range_for_corrected_data = 100
    @bad_data = 0
    @data_problems = {}
  end

  def validate
    puts "=" * 150
    puts "Validating meter data of type #{@meter.meter_type} #{@meter.name} #{@meter.id}"
    # ap(@meter, limit: 5, :color => {:float  => :red})
    check_for_long_gaps_in_data
    fill_in_missing_data
    puts "=" * 150
  end

  def check_for_long_gaps_in_data
    gap_count = 0
    first_bad_date = Date.new(2050, 1, 1)
    (@amr_data.start_date..@amr_data.end_date).reverse_each do |date|
      if !@amr_data.key?(date)
        first_bad_date = date if gap_count.zero?
        gap_count += 1
      else
        gap_count = 0
      end
      if gap_count > @max_days_missing_data
        min_date = first_bad_date + 1
        @amr_data.set_min_date(min_date)
        msg =  'Ignoring all data before ' + min_date.strftime(FSTRDEF)
        msg += ' as gap of more than ' + @max_days_missing_data.to_s + ' days '
        msg += (@amr_data.keys.index(min_date) - 1).to_s + ' days of data ignored'
        @data_problems['Too much missing data'] = msg
      end
    end
  end

  def fill_in_missing_data
    missing_days = {}
    puts "Looking for missing amr data between #{@amr_data.start_date} #{@amr_data.end_date}"
    (@amr_data.start_date..@amr_data.end_date).each do |date|
      if !@amr_data.key?(date)
        if @meter.meter_type == :electricity || @meter.meter_type == 'electricity'
          missing_days[date] = substitute_missing_electricity_data(date)
        elsif @meter.meter_type == :gas || @meter.meter_type == 'gas'
          missing_days[date] = substitute_missing_gas_data(date)
        end
      end
    end

    list_of_date_substitutions = []
    missing_days.each do |date, corrected_data|
      if corrected_data.nil?
        msg = "Fatal error with meter #{@meter.id} #{@meter.meter_type} unable to correct missing data for " + date.strftime(FSTRDEF)
        @data_problems['Too much missing data'] = msg
      else
        substitute_date, substitute_data = corrected_data
        list_of_date_substitutions.push(date.strftime(FSTRDEF) + '<=' + substitute_date.strftime(FSTRDEF))
        @data_problems['Missing data ' + date.strftime(FSTRDEF)] = msg
        @amr_data.add(date, substitute_data.clone)
      end
    end

    if !list_of_date_substitutions.empty?
      puts "The following date substitutions are being made for missing data:"
      list_of_date_substitutions.each_slice(4) do |group_of_four|
        puts group_of_four.to_s
      end
    end
  end

  # iterate out from missing data date, looking for a similar day without missing data
  def substitute_missing_electricity_data(date)
    missing_daytype = daytype(date)
    (1..@max_search_range_for_corrected_data).each do |days_offset|
      # look for similar day after the missing date
      day_after = date + days_offset
      if day_after <= @amr_data.end_date &&
          @amr_data.key?(day_after) &&
          daytype(day_after) == missing_daytype
        return [day_after, @amr_data[day_after]]
      end
      # look for similar day before the missing date
      day_before = date - days_offset
      if day_before >= @amr_data.start_date &&
          @amr_data.key?(day_before) &&
          daytype(day_before) == missing_daytype
        return [day_before, @amr_data[day_before]]
      end
    end
    nil
  end

  # iterate put from missing data, looking for a similar day without missing data
  # then adjust for temperature
  def substitute_missing_gas_data(date)
    create_heating_model if @heating_model.nil?
    heating_on = @heating_model.heating_on?(date)
    missing_daytype = daytype(date)
    avg_temperature = average_temperature(date)
    (1..@max_search_range_for_corrected_data).each do |days_offset|
      # look for similar day after the missing date
      day_after = date + days_offset
      if day_after <= @amr_data.end_date && @amr_data.key?(day_after)
        temperature_after = average_temperature(day_after)
        if heating_on == @heating_model.heating_on?(day_after) &&
            within_temperature_range?(avg_temperature, temperature_after) &&
            daytype(day_after) == missing_daytype
          return [day_after, adjusted_substitute_heating_kwh(date, day_after)]
        end
      end
      # look for similar day before the missing date
      day_before = date - days_offset
      temperature_before = average_temperature(day_before)
      if day_before >= @amr_data.start_date &&
          @amr_data.key?(day_before) &&
          heating_on == @heating_model.heating_on?(day_before) &&
          within_temperature_range?(avg_temperature, temperature_before) &&
          daytype(day_before) == missing_daytype
        return [day_before, adjusted_substitute_heating_kwh(date, day_before)]
      end
    end
    puts "Error: Unable to find suitable substitute for missing day of gas data #{date} temperature #{avg_temperature.round(0)}"
    nil
  end

  def average_temperature(date)
    begin
      @temperatures.average_temperature(date)
    rescue StandardError => _e
      puts "Warning: problem generating missing gas data, as no temperature data for #{date}"
      raise
    end
  end

  def within_temperature_range?(day_temp, substitute_temp)
    criteria = MAXGASAVGTEMPDIFF * (day_temp < 20.0 ? 1.0 : 1.5) # relax criteria in summer
    (day_temp - substitute_temp).magnitude < criteria
  end

  def adjusted_substitute_heating_kwh(missing_day, substitute_day)
    _temp_diff = @temperatures.average_temperature(missing_day) - @temperatures.average_temperature(substitute_day)

    kwh_prediction_for_missing_day = @heating_model.predicted_kwh(missing_day, @temperatures.average_temperature(missing_day))
    kwh_prediction_for_substitute_day = @heating_model.predicted_kwh(substitute_day, @temperatures.average_temperature(substitute_day))
    prediction_ratio = kwh_prediction_for_missing_day / kwh_prediction_for_substitute_day
    if prediction_ratio < 0
      puts "Warning: negative predicated data for missing day #{missing_day} from #{substitute_day} setting to zero"
      prediction_ratio = 0.0
    end
    substitute_data = Array.new(48, 0.0)
    (0..47).each do |halfhour_index|
      # scale substitutes missing day data by ratio of predicted kwh's (not ideal as will scale baseload as well)
      # TODO(PH,28May2018): at some point do more sophisticated adjustment, which potentially
      #                   : scales base load differently- very low priority requirement
      substitute_data[halfhour_index] = @amr_data.kwh(substitute_day, halfhour_index) * prediction_ratio
    end
    puts "Gas Adjustment For Missing Data: replacing #{missing_day} with #{substitute_day}"
    puts "sub kWh = #{kwh_prediction_for_missing_day} missing replacement  #{kwh_prediction_for_substitute_day}"
    puts "actual #{@amr_data.one_day_kwh(substitute_day)} temp diff #{_temp_diff} ratio = #{prediction_ratio}"
    substitute_data
  end

  def create_heating_model
    @heating_model = AnalyseHeatingAndHotWater::BasicRegressionHeatingModel.new(@amr_data, @holidays, @temperatures)
    @heating_model.calculate_regression_model(SchoolDatePeriod.new(:validation, 'Validation Period', @amr_data.start_date, @amr_data.end_date))
    @heating_model.calculate_heating_periods(@amr_data.start_date, @amr_data.end_date)
  end

  def daytype(date)
    if @holidays.holiday?(date)
      weekend?(date) ? :holidayandweekend : :holidayweekday
    else
      weekend?(date) ? :weekend : :weekday
    end
  end

  def weekend?(date)
    date.sunday? || date.saturday?
  end
end
