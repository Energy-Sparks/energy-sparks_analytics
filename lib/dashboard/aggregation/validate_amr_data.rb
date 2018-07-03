
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
    unless @meter.meter_correction_rules.nil?
      puts "$" * 300 if meter.meter_correction_rules
      puts "Meter Correction Rules"
      puts @meter.meter_correction_rules.inspect
    end
    add_meter_correction_rules
  end

  def add_meter_correction_rules
    MeterAdjustments.meter_adjustment(@meter)
  end

  def validate
    puts "=" * 150
    puts "Validating meter data of type #{@meter.meter_type} #{@meter.name} #{@meter.id}"
    # ap(@meter, limit: 5, :color => {:float  => :red})
    meter_corrections unless @meter.meter_correction_rules.nil?
    check_for_long_gaps_in_data
    fill_in_missing_data
    correct_holidays_with_adjacent_academic_years
    final_report_for_missing_data_set_to_small_negative
    puts "=" * 150
  end

  def meter_corrections
    puts '-' * 80
    puts 'Manually defined meter corrections'
    if @meter.meter_correction_rules.key?(:rescale_amr_data)
      scale_amr_data(
        @meter.meter_correction_rules[:rescale_amr_data][:start_date],
        @meter.meter_correction_rules[:rescale_amr_data][:end_date],
        @meter.meter_correction_rules[:rescale_amr_data][:scale]
      )
    end
    if @meter.meter_correction_rules.key?(:readings_start_date)
      puts "Fixing start date to #{@meter.meter_correction_rules[:readings_start_date]}"
      @amr_data.set_min_date(@meter.meter_correction_rules[:readings_start_date])
    end
    if @meter.meter_correction_rules.key?(:auto_insert_missing_readings)
     if @meter.meter_correction_rules[:auto_insert_missing_readings] == :weekends
      replace_missing_weekend_data_with_zero
     else
      val = @meter.meter_correction_rules[auto_insert_missing_readings]
      raise EnergySparksMeterSpecification.new("unknown auto_insert_missing_readings meter attribute #{val}")
     end
    end
  end

  # typically is imperial to metric meter readings aren't corrected to kWh properly at source
  def scale_amr_data(start_date, end_date, scale)
    puts "Scaling data between #{start_date} and #{end_date} by #{scale} - imperial to SI conversion?"
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
      puts "Searching for matching missing holiday data for #{date} from subsequent or previous academic years"
      begin
        holiday_type = @holidays.type(date)
        hol = similar_holiday(date, holiday_type, 1) # try following academic year
        if hol.nil? || hol.end_date > @amr_data.end_date # assume temperatures always have more data than amr, so don't test
          puts "Warning: no holiday data for following year trying previous year" if hol.nil?
          puts 'Trying previous holiday as no amr data for the subsequent holiday period' if !hol.nil? && hol.end_date > @amr_data.end_date
          puts 'Trying previous year instead'
          hol = similar_holiday(date, holiday_type, -1) # try previous academic year
        end
        if hol.nil? || hol.end_date > @amr_data.end_date || hol.start_date < @amr_data.start_date
          puts "Warning: unable to find suitable replacement holiday periods for #{date}"
          if hol.nil?
            puts 'Because cannot find suitable holiday'
          elsif hol.end_date > @amr_data.end_date || hol.start_date < @amr_data.start_date
            puts 'Because no amr data for holiday'
          else
            puts 'Because of an unknown reason'
          end
        else
          puts "Planning on correcting with #{hol.start_date} #{hol.end_date}"
          adjusted_date = find_similar_day_of_the_week(hol, date.wday)
          if @meter.meter_type == :electricity
            put "Correcting missing electricity holiday on #{date} with data from #{adjusted_date}"
            @amr_data.add(date, @amr_data[adjusted_date])
          elsif @meter.meter_type == :gas
            # perhaps would be better if substitute similar weekday had matching temperatures?
            # probably better this way if thermally massive building?
            if @amr_data.key?(adjusted_date)
              puts "Correcting missing gas holiday on #{date} with data from #{adjusted_date}"
              @amr_data.add(date, adjusted_substitute_heating_kwh(date, adjusted_date))
            else
              puts "Warning: unable to find substitute holiday data for #{date} as substitute data #{adjusted_date} has no AMR data"
              puts "Warning: setting this date #{date} to zero"
              @amr_data.add(date, Array.new(48, 0.0)) # have to assume if no replacement holiday reading gas was completely off
            end
          end
        end
      rescue EnergySparksUnexpectedStateException => e
        puts "Comment: deliberately rescued missing holiday data exception for date #{date}"
        puts e.message
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
          puts "Unable to find holiday of type #{holiday_type} and date #{date}  and offset #{year_offset}"
          return nil
        else
          puts "Got similar holiday for date #{hols.start_date} #{hols.end_date}"
          return hols
        end
      else
        return nil
      end
    end
  end

  def final_report_for_missing_data_set_to_small_negative
    puts '>' * 100
    puts "For meter of type #{@meter.meter_type} #{@meter.name} #{@meter.id}:"
    puts 'At the end of the meter validation process the following amr data is still missing (setting to 0.0123456):'
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
    puts '>' * 100
  end

  def replace_missing_weekend_data_with_zero
    puts "Setting missing weekend dates to zero"
    replaced_dates = []
    (@amr_data.start_date..@amr_data.end_date).each do |date|
      if DateTimeHelper.weekend?(date) && !@amr_data.key?(date)
        replaced_dates.push(date)
        @amr_data.add(date, Array.new(48, 0.0))
      end
    end
    puts 'Replaced the following weekend dates:'
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
    puts "GOTTTT Here #{date}"
    debug = date.year == 2017 && date.month == 2 && date.day == 12
    create_heating_model if @heating_model.nil?
    heating_on = @heating_model.heating_on?(date)
    missing_daytype = daytype(date)
    avg_temperature = average_temperature(date)
    puts "Got Checked Missing Date #{date} heat on #{heating_on} day type #{missing_daytype} temperature #{avg_temperature}" if debug
    (1..@max_search_range_for_corrected_data).each do |days_offset|
      # look for similar day after the missing date
      day_after = date + days_offset
      puts "Trying #{day_after} got amr data: #{@amr_data.key?(day_after)}" if debug
      if day_after <= @amr_data.end_date && @amr_data.key?(day_after)
        temperature_after = average_temperature(day_after)
        puts "Temperature = #{temperature_after} heat on #{@heating_model.heating_on?(day_after)} heat on #{daytype(day_after)}" if debug
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
    puts "Error: Unable to find suitable substitute for missing day of gas data #{date} temperature #{avg_temperature.round(0)} daytype #{missing_daytype}"
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
