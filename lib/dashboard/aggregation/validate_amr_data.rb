
# validates AMR data
# - checks for missing data
#   - if there is too big a gap it reduces the start and end dates for the amr data
#   - if there are smaller gaps it attempts to fill them in using nearby data
#   - and if its heat/gas data then it adjusts for temperature
class ValidateAMRData
  include Logging

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
    unless @meter.meter_correction_rules.nil?
      logger.debug "$" * 300 if meter.meter_correction_rules
      logger.debug "Meter Correction Rules"
      logger.debug @meter.meter_correction_rules.inspect
    end
    add_meter_correction_rules
  end

  def add_meter_correction_rules
    MeterAdjustments.meter_adjustment(@meter)
  end

  def validate
    logger.debug "=" * 150
    logger.debug "Validating meter data of type #{@meter.meter_type} #{@meter.name} #{@meter.id}"
    # ap(@meter, limit: 5, :color => {:float  => :red})
    check_for_long_gaps_in_data
    meter_corrections unless @meter.meter_correction_rules.nil?
    fill_in_missing_data
    correct_holidays_with_adjacent_academic_years
    final_report_for_missing_data_set_to_small_negative
    logger.debug "=" * 150
  end

  def meter_corrections
    unless @meter.meter_correction_rules.nil?
      @meter.meter_correction_rules.each do |rule|
        apply_one_meter_correction(rule)
      end
    end
  end

  def apply_one_meter_correction(rule)
    logger.debug '-' * 80
    logger.debug 'Manually defined meter corrections'
    if rule.key?(:rescale_amr_data)
      scale_amr_data(
        rule[:rescale_amr_data][:start_date],
        rule[:rescale_amr_data][:end_date],
        rule[:rescale_amr_data][:scale]
      )
    end
    if rule.key?(:readings_start_date)
      logger.debug "Fixing start date to #{rule[:readings_start_date]}"
      @amr_data.set_min_date(rule[:readings_start_date])
    end
    if rule.key?(:auto_insert_missing_readings)
      if (rule[:auto_insert_missing_readings].is_a?(Symbol) && # backwards compatibility
          rule[:auto_insert_missing_readings] == :weekends) ||
          rule[:auto_insert_missing_readings][:type]== :weekends
        replace_missing_weekend_data_with_zero
      elsif rule[:auto_insert_missing_readings][:type] == :date_range
        replace_missing_data_with_zero(
          rule[:auto_insert_missing_readings][:start_date],
          rule[:auto_insert_missing_readings][:end_date]
        )
      else
        val = rule[:auto_insert_missing_readings]
        raise EnergySparksMeterSpecification.new("unknown auto_insert_missing_readings meter attribute #{val}")
      end
    end
  end

  # typically is imperial to metric meter readings aren't corrected to kWh properly at source
  def scale_amr_data(start_date, end_date, scale)
    logger.debug "Scaling data between #{start_date} and #{end_date} by #{scale} - imperial to SI conversion?"
    start_date = @amr_data.start_date if @amr_data.start_date > start_date # case where another correction has changed data prior to confiured correction
    (start_date..end_date).each do |date|
      if @amr_data.key?(date)
        data_x48 = @amr_data[date]
        (0..47).each do |halfhour_index|
          data_x48[halfhour_index] *= scale
        end
        @amr_data.add(date, data_x48)
      end
    end
  end

  def correct_holidays_with_adjacent_academic_years
    missing_holiday_dates = []
    (@amr_data.start_date..@amr_data.end_date).each do |date|
      missing_holiday_dates.push(date) if !@amr_data.key?(date) && @holidays.holiday?(date)
    end

    missing_holiday_dates.each do |date|
      logger.debug "Searching for matching missing holiday data for #{date} from subsequent or previous academic years"
      begin
        holiday_type = @holidays.type(date)
        hol = similar_holiday(date, holiday_type, 1) # try following academic year
        if hol.nil? || hol.end_date > @amr_data.end_date # assume temperatures always have more data than amr, so don't test
          logger.debug "Warning: no holiday data for following year trying previous year" if hol.nil?
          logger.debug 'Trying previous holiday as no amr data for the subsequent holiday period' if !hol.nil? && hol.end_date > @amr_data.end_date
          logger.debug 'Trying previous year instead'
          hol = similar_holiday(date, holiday_type, -1) # try previous academic year
        end
        if hol.nil? || hol.end_date > @amr_data.end_date || hol.start_date < @amr_data.start_date
          logger.debug "Warning: unable to find suitable replacement holiday periods for #{date}"
          if hol.nil?
            logger.debug 'Because cannot find suitable holiday'
          elsif hol.end_date > @amr_data.end_date || hol.start_date < @amr_data.start_date
            logger.debug 'Because no amr data for holiday'
          else
            logger.debug 'Because of an unknown reason'
          end
        else
          logger.debug "Planning on correcting with #{hol.start_date} #{hol.end_date}"
          adjusted_date = find_similar_day_of_the_week(hol, date.wday)
          if @meter.meter_type == :electricity
            logger.debug "Correcting missing electricity holiday on #{date} with data from #{adjusted_date}"
            @amr_data.add(date, @amr_data[adjusted_date])
          elsif @meter.meter_type == :gas
            # perhaps would be better if substitute similar weekday had matching temperatures?
            # probably better this way if thermally massive building?
            if @amr_data.key?(adjusted_date)
              logger.debug "Correcting missing gas holiday on #{date} with data from #{adjusted_date}"
              @amr_data.add(date, adjusted_substitute_heating_kwh(date, adjusted_date))
            else
              logger.debug "Warning: unable to find substitute holiday data for #{date} as substitute data #{adjusted_date} has no AMR data"
              logger.debug "Warning: setting this date #{date} to zero"
              @amr_data.add(date, Array.new(48, 0.0)) # have to assume if no replacement holiday reading gas was completely off
            end
          end
        end
      rescue EnergySparksUnexpectedStateException => e
        logger.error "Comment: deliberately rescued missing holiday data exception for date #{date}"
        logger.error e.message
      end
    end
  end

  def find_similar_day_of_the_week(holiday_period, day_of_week)
    (holiday_period.start_date..holiday_period.end_date).each do |date|
      return date if date.wday == day_of_week
    end
    holiday_period.start_date # worst case just return the 1st day
  end

  def similar_holiday(date, holiday_type, year_offset)
    unless holiday_type.nil?
      nth_academic_year = @holidays.nth_academic_year_from_date(year_offset, date, false)
      unless nth_academic_year.nil?
        hols = @holidays.find_holiday_in_academic_year(nth_academic_year, holiday_type)
        if hols.nil?
          logger.warn "Unable to find holiday of type #{holiday_type} and date #{date}  and offset #{year_offset}"
          return nil
        else
          logger.debug "Got similar holiday for date #{hols.start_date} #{hols.end_date}"
          return hols
        end
      else
        return nil
      end
    end
  end

  def final_report_for_missing_data_set_to_small_negative
    logger.info '>' * 100
    logger.info "For meter of type #{@meter.meter_type} #{@meter.name} #{@meter.id}:"
    logger.info 'At the end of the meter validation process the following amr data is still missing (setting to 0.0123456):'
    missing_dates = []
    (@amr_data.start_date..@amr_data.end_date).each do |date|
      if !@amr_data.key?(date)
        missing_dates.push(date)
      end
    end
    print_array_of_dates_in_columns(missing_dates, 4, STDERR)
    print_array_of_dates_in_columns(missing_dates, 4, STDOUT)
    missing_dates.each do |date|
      @amr_data.add(date, Array.new(48, 0.0123456))
    end
    logger.info '>' * 100
  end

  def replace_missing_weekend_data_with_zero
    logger.debug "Setting missing weekend dates to zero"
    replaced_dates = []
    (@amr_data.start_date..@amr_data.end_date).each do |date|
      if DateTimeHelper.weekend?(date) && !@amr_data.key?(date)
        replaced_dates.push(date)
        @amr_data.add(date, Array.new(48, 0.0))
      end
    end
    logger.debug 'Replaced the following weekend dates:'
    print_array_of_dates_in_columns(replaced_dates, 8)
  end

  def replace_missing_data_with_zero(start_date, end_date)
    logger.debug "Setting missing data between #{start_date.strftime('%a %d %b %Y')} and #{end_date.strftime('%a %d %b %Y')} to zero"
    replaced_dates = []
    start_date = start_date.nil? ? @amr_data.start_date : start_date
    end_date = end_date.nil? ? @amr_data.end_date : end_date
    (start_date..end_date).each do |date|
      if !@amr_data.key?(date)
        replaced_dates.push(date)
        @amr_data.add(date, Array.new(48, 0.0))
      end
    end
    logger.debug 'Replaced the following dates:'
    print_array_of_dates_in_columns(replaced_dates, 8)
  end

  # quick and dirty implementation TODO(PH,20Jun2018) - could be improved
  def print_array_of_dates_in_columns(dates, number_of_columns, output = STDOUT)
    count = 0
    dates.each do |date|
      output.print date.strftime('%a %d %b %Y') + ' '
      output.puts if count % number_of_columns == (number_of_columns - 1)
      count += 1
    end
    output.puts
  end

  def in_meter_correction_period?(date)
    @meter.meter_correction_rules.each do |rule|
      if rule.key?(:auto_insert_missing_readings) &&
         rule[:auto_insert_missing_readings][:type] == :date_range
        if date >= rule[:auto_insert_missing_readings][:start_date] &&
            date <= rule[:auto_insert_missing_readings][:end_date]
          return true
        end
      end
    end
    false
  end

  def check_for_long_gaps_in_data
    logger.debug "Checking for long gaps"
    gap_count = 0
    first_bad_date = Date.new(2050, 1, 1)
    (@amr_data.start_date..@amr_data.end_date).reverse_each do |date|
      if !@amr_data.key?(date)
        first_bad_date = date if gap_count.zero?
        gap_count += 1
      else
        gap_count = 0
      end
      if gap_count > @max_days_missing_data && !in_meter_correction_period?(date)
        min_date = first_bad_date + 1
        @amr_data.set_min_date(min_date)
        msg =  'Ignoring all data before ' + min_date.strftime(FSTRDEF)
        msg += ' as gap of more than ' + @max_days_missing_data.to_s + ' days '
        msg += (@amr_data.keys.index(min_date) - 1).to_s + ' days of data ignored'
        @data_problems['Too much missing data'] = msg
        logger.debug msg
        break
      end
    end
  end

  def fill_in_missing_data
    missing_days = {}
    logger.debug "Looking for missing amr data between #{@amr_data.start_date} #{@amr_data.end_date}"
    (@amr_data.start_date..@amr_data.end_date).each do |date|
      if !@amr_data.key?(date)
        if @meter.meter_type == :electricity
          missing_days[date] = substitute_missing_electricity_data(date)
        elsif @meter.meter_type == :gas
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
      logger.debug "The following date substitutions are being made for missing data:"
      list_of_date_substitutions.each_slice(4) do |group_of_four|
        logger.debug group_of_four.to_s
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
    logger.debug "GOTTTT Here #{date}"
    debug = date.year == 2017 && date.month == 2 && date.day == 12
    create_heating_model if @heating_model.nil?
    heating_on = @heating_model.heating_on?(date)
    missing_daytype = daytype(date)
    avg_temperature = average_temperature(date)

    logger.debug "Got Checked Missing Date #{date} heat on #{heating_on} day type #{missing_daytype} temperature #{avg_temperature}" if debug
    (1..@max_search_range_for_corrected_data).each do |days_offset|
      # look for similar day after the missing date
      day_after = date + days_offset

      logger.debug "Trying #{day_after} got amr data: #{@amr_data.key?(day_after)}" if debug
      if day_after <= @amr_data.end_date && @amr_data.key?(day_after)
        temperature_after = average_temperature(day_after)
        logger.debug "Temperature = #{temperature_after} heat on #{@heating_model.heating_on?(day_after)} heat on #{daytype(day_after)}" if debug
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
    logger.debug "Error: Unable to find suitable substitute for missing day of gas data #{date} temperature #{avg_temperature.round(0)} daytype #{missing_daytype}"
    nil
  end

  def average_temperature(date)
    begin
      @temperatures.average_temperature(date)
    rescue StandardError => _e
      logger.error "Warning: problem generating missing gas data, as no temperature data for #{date}"
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
      logger.debug "Warning: negative predicated data for missing day #{missing_day} from #{substitute_day} setting to zero"
      prediction_ratio = 0.0
    end
    substitute_data = Array.new(48, 0.0)
    (0..47).each do |halfhour_index|
      # scale substitutes missing day data by ratio of predicted kwh's (not ideal as will scale baseload as well)
      # TODO(PH,28May2018): at some point do more sophisticated adjustment, which potentially
      #                   : scales base load differently- very low priority requirement
      substitute_data[halfhour_index] = @amr_data.kwh(substitute_day, halfhour_index) * prediction_ratio
    end
    logger.debug "Gas Adjustment For Missing Data: replacing #{missing_day} with #{substitute_day}"
    logger.debug "sub kWh = #{kwh_prediction_for_missing_day} missing replacement  #{kwh_prediction_for_substitute_day}"
    logger.debug "actual #{@amr_data.one_day_kwh(substitute_day)} temp diff #{_temp_diff} ratio = #{prediction_ratio}"
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
