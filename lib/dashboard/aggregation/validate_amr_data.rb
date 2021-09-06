
# validates AMR data
# - checks for missing data
#   - if there is too big a gap it reduces the start and end dates for the amr data
#   - if th
# validates AMR data
# - checks for missing data
#   - if there is too big a gap it reduces the start and end dates for the amr data
#   - if there are smaller gaps it attempts to fill them in using nearby data
#   - and if its heat/gas data then it adjusts for temperature
class ValidateAMRData
  class NotEnoughTemperaturedata < StandardError; end

  include Logging

  FSTRDEF = '%a %d %b %Y'.freeze # fixed format for reporting dates for error messages
  MAXGASAVGTEMPDIFF = 5 # max average temperature difference over which to adjust temperatures
  MAXSEARCHRANGEFORCORRECTEDDATA = 100
  NO_MODEL = 0 # model calc failed
  attr_reader :data_problems, :meter_id
  def initialize(meter, max_days_missing_data, holidays, temperatures)
    @amr_data = meter.amr_data
    @meter = meter
    @meter_id = @meter.mpan_mprn
    @type = meter.meter_type
    @holidays = holidays
    @temperatures = temperatures
    @max_days_missing_data = max_days_missing_data
    @bad_data = 0
    @run_date = Date.today - 4 # TODO(PH,16Sep2019): needs rethink
    @data_problems = {}
  end

  def validate(debug_analysis = false)
    logger.debug "=" * 150
    assess_null_data if debug_analysis
    logger.debug "Validating meter data of type #{@meter.meter_type} #{@meter.name} #{@meter.id}"
    logger.debug "Meter data from #{@meter.amr_data.start_date} to #{@meter.amr_data.end_date}"
    logger.debug "DCC Meter #{@meter.dcc_meter}"
    puts "Before validation #{missing_data} missing items of data" if debug_analysis
    remove_final_meter_reading_if_today
    check_temperature_data_covers_gas_meter_data_range
    # ap(@meter, limit: 5, :color => {:float  => :red})
    process_meter_attributes
    remove_dcc_bad_data_readings if @meter.dcc_meter
    correct_nil_readings
    meter_corrections unless @meter.meter_correction_rules.nil?
    check_for_long_gaps_in_data
    # meter_corrections unless @meter.meter_correction_rules.nil?
    fill_in_missing_data
    correct_holidays_with_adjacent_academic_years
    final_missing_data_set_to_small_negative
    @amr_data.summarise_bad_data
    if debug_analysis
      puts "After validation #{missing_data} missing items of data"
      ap missing_data_stats
      assess_null_data if debug_analysis
    end
    logger.debug "=" * 150
  end

  private

  def heating_model
    @heating_model ||= create_heating_model
  end

  def process_meter_attributes
    meter_attributes_corrections = @meter.attributes(:meter_corrections)
    if meter_attributes_corrections.nil?
      auto_insert_for_gas_if_no_other_rules
    else
      @meter.insert_correction_rules_first(meter_attributes_corrections)
    end
  end

  def auto_insert_for_gas_if_no_other_rules
    return unless @type.to_sym == :gas
    logger.info "Adding auto insert missing readings as we're a gas meter & no other corrections"
    @meter.insert_correction_rules_first([{ auto_insert_missing_readings: { type: :weekends } }])
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
    logger.debug "Manually defined meter corrections: #{rule}"
    if rule.is_a?(Symbol) && rule == :set_all_missing_to_zero
      logger.debug 'Setting all missing data to zero'
      set_all_missing_data_to_zero
    elsif rule.is_a?(Symbol) && rule == :correct_zero_partial_data
      logger.debug 'Correcting partially missing (zero) data'
      correct_zero_partial_data
    elsif rule.key?(:rescale_amr_data)
      scale_amr_data(
        rule[:rescale_amr_data][:start_date],
        rule[:rescale_amr_data][:end_date],
        rule[:rescale_amr_data][:scale]
      )
    elsif rule.key?(:readings_start_date)
      fix_start_date = rule[:readings_start_date]
      logger.debug "Fixing start date to #{fix_start_date}"
      substitute_data_x48 = @amr_data.one_days_data_x48(fix_start_date)
      @amr_data.add(fix_start_date, OneDayAMRReading.new(meter_id, fix_start_date, 'FIXS', nil, DateTime.now, substitute_data_x48))
      @amr_data.set_start_date(fix_start_date)
    elsif rule.key?(:readings_end_date)
      fix_end_date = rule[:readings_end_date]
      logger.debug "Fixing end date to #{fix_end_date}"
      substitute_data_x48 = @amr_data.one_days_data_x48(fix_end_date)
      @amr_data.add(fix_end_date, OneDayAMRReading.new(meter_id, fix_end_date, 'FIXE', nil, DateTime.now, substitute_data_x48))
      @amr_data.set_end_date(fix_end_date)
    elsif rule.key?(:set_bad_data_to_zero)
      zero_data_in_date_range(
        rule[:set_bad_data_to_zero][:start_date],
        rule[:set_bad_data_to_zero][:end_date]
      )
    elsif rule.key?(:set_missing_data_to_zero)
      zero_missing_data_in_date_range(
        rule[:set_missing_data_to_zero][:start_date],
        rule[:set_missing_data_to_zero][:end_date]
      )
    elsif rule.key?(:auto_insert_missing_readings)
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
    elsif rule.key?(:no_heating_in_summer_set_missing_to_zero)
      logger.debug 'Got missing summer rule'
      set_missing_data_to_zero_on_heating_meter_during_summer(
        rule[:no_heating_in_summer_set_missing_to_zero][:start_toy],
        rule[:no_heating_in_summer_set_missing_to_zero][:end_toy],
      )
    elsif rule.key?(:override_bad_readings)
      fill_in_missing_data(
        rule[:override_bad_readings][:start_date],
        rule[:override_bad_readings][:end_date],
        'X',
        true
      )
    elsif rule.key?(:extend_meter_readings_for_substitution)
      extend_start_date(rule[:extend_meter_readings_for_substitution][:start_date]) if rule[:extend_meter_readings_for_substitution].key?(:start_date)
      extend_end_date(  rule[:extend_meter_readings_for_substitution][:end_date])   if rule[:extend_meter_readings_for_substitution].key?(:end_date)
=begin
# deprecated PH 13Apr2021
    elsif rule.key?(:meter_corrections_use_sheffield_pv_data) || rule.key?(:set_to_sheffield_pv_data)
      config = rule[:meter_corrections_use_sheffield_pv_data] || rule[:set_to_sheffield_pv_data]
      override_with_sheffield_solar_pv_data(config[:start_date], config[:end_date])
=end
    end
  end

  def extend_start_date(date)
    logger.info "Extending start date to #{date}"
    @amr_data.set_start_date(date)
  end

  def extend_end_date(date)
    logger.info "Extending end date to #{date}"
    @amr_data.set_end_date(date)
  end

  def set_all_missing_data_to_zero_by_time_of_year(start_toy, end_toy, type)
    year_count = {}
    end_date = @amr_data.end_date > @run_date ? @amr_data.end_date : @run_date
    (@amr_data.start_date..end_date).each do |date|
      toy = TimeOfYear.new(date.month, date.day)
      if @amr_data.date_missing?(date) && toy >= start_toy && toy <= end_toy
        zero_data = Array.new(48, 0.0)
        data = OneDayAMRReading.new(meter_id, date, type, nil, DateTime.now, zero_data)
        @amr_data.add(date, data)

        year_count[date.year] = 0 unless year_count.key?(date.year)
        year_count[date.year] += 1
      end
    end
    year_count.each do |year, count|
      logger.info "set during #{year} * #{count} to zero"
    end
  end

  def remove_dcc_bad_data_readings
    logger.info 'Checking dcc meter for bad values'
    too_much_bad_data = {}
    for_interpolation = {}
    ok_data = {}
    (@amr_data.start_date..@amr_data.end_date).each do |date|
      if @amr_data.date_exists?(date)
        days_kwh_x48 = @amr_data.days_kwh_x48(date)
        bad_value_count = days_kwh_x48.count{ |kwh| bad_dcc_value?(kwh) }
        if bad_value_count > 7
          too_much_bad_data[date] = bad_value_count
        elsif bad_value_count > 0
          for_interpolation[date] = bad_value_count
        else
          ok_data[date] = 0
        end
      end
    end

    if too_much_bad_data.length > 0
      logger.info "The following dates have too much DCC bad data, so removing them for future whole day substitution"
      log_dates(too_much_bad_data)
      too_much_bad_data.each do |date, _count|
        @amr_data.delete(date)
      end
    end

    if for_interpolation.length > 0
      logger.info 'The following dates have bad half hour kWh value, so nullifying for future interpolation'
      log_dates(for_interpolation)
      for_interpolation.each do |date, count|
        days_kwh_x48 = @amr_data.days_kwh_x48(date)
        days_kwh_x48.map!{ |kwh| bad_dcc_value?(kwh) ? nil : kwh }
        data = OneDayAMRReading.new(meter_id, date, 'DCCP', nil, DateTime.now, days_kwh_x48)
        @amr_data.add(date, data)
      end
    end

    logger.info "Leaving #{ok_data.length} days of dcc data with no bad values"
  end

  # typical problem for DCC provided data, has partial data for today from 4.00am batch
  def remove_final_meter_reading_if_today
    if @meter.amr_data.end_date >= Date.today
      (Date.today..@meter.amr_data.end_date).each do |date|
        # would assume, unless spurious future readings are provided that the code only loops once
        @amr_data.set_end_date(date - 1)
        logger.info "Removing final partial dcc meter reading for today #{date}"
      end
    end
  end

  def log_dates(ds)
    ds.keys.each_slice(8) do |dates|
      logger.info dates.map{ |d| d.strftime('%d-%b-%Y') }.join(' ')
    end
  end

  def bad_dcc_value?(kwh)
    # there may be other bad values in future
    # none of this is documented by the DCC......
    kwh.between?(186227.0864, 186227.0866)
  end

  def correct_nil_readings
    remove_missing_start_end_dates_if_partial_nil
    correct_zero_partial_data(missing_data_value: nil)
    # leave the rest of the validation to fix whole missing days
  end

  def remove_missing_start_end_dates_if_partial_nil
    if @amr_data.days_kwh_x48(@amr_data.start_date).any?(&:nil?)
      logger.info "Moving meter start date #{@amr_data.start_date} 1 day forward as only partial data on start date"
      @amr_data[@amr_data.start_date].set_type('PSTD')
      @amr_data.set_start_date(@amr_data.start_date + 1)
    end

    if @amr_data.days_kwh_x48(@amr_data.end_date).any?(&:nil?)
      logger.info "Moving meter end date #{@amr_data.end_date} one day back as only partial data on end date"
      @amr_data[@amr_data.end_date].set_type('PETD')
      @amr_data.set_start_date(@amr_data.end_date - 1)
    end
  end

  # the Frome/Somerset csv feed has a small amount of zero data in its electricity csv feeds
  # sometimes its just a few points, sometimes its a whole day (with BST/GMT offset issues!)
  def correct_zero_partial_data(max_missing_readings: 6, missing_data_value: 0.0)
    # do this is a particular order to avoid substitiing partial data
    # with partial data

    missing_dates = remove_readings_with_too_many_missing_partial_readings(max_missing_readings, missing_data_value)

    interpolate_partial_missing_data(max_missing_readings, missing_data_value)

    substitute_partial_missing_data_with_whole_day(missing_dates)
  end

  def interpolate_partial_missing_data(max_missing_readings, missing_data_value)
    (@amr_data.start_date..@amr_data.end_date).each do |date|
      if @amr_data.date_exists?(date)
        days_kwh_x48 = @amr_data.days_kwh_x48(date)
        num_zero_values = days_kwh_x48.count(missing_data_value)
        if num_zero_values > 0 && num_zero_values <= max_missing_readings
          days_kwh_x48 = interpolate_zero_readings(days_kwh_x48, missing_data_value: missing_data_value)
          type = (@meter.dcc_meter ? 'DMP' : 'CMP') + num_zero_values.to_s
          updated_data = OneDayAMRReading.new(meter_id, date, type, nil, DateTime.now, days_kwh_x48)
          @amr_data.add(date, updated_data)
        end
      end
    end
  end

  def assess_null_data
    count = (@amr_data.start_date..@amr_data.end_date).sum do |date|
      @amr_data.date_missing?(date) ? 48 : @amr_data.days_kwh_x48(date).count(&:nil?)
    end
    puts ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>Items of nil data #{count} for #{@meter.mpan_mprn}"
  end

  def missing_data_stats
    stats = Hash.new { |h, k| h[k] = 0 }
    (@amr_data.start_date..@amr_data.end_date).each do |date|
      stats[@amr_data.substitution_type(date)] += 1
    end
    stats
  end

  def missing_data
    missing = (@amr_data.start_date..@amr_data.end_date).count { |date| @amr_data.date_missing?(date) }
  end

  def substitute_partial_missing_data_with_whole_day(missing_dates)
    missing_dates.each do |date|
      date, updated_one_day_reading = substitute_missing_electricity_data(date, 'S')
      unless updated_one_day_reading.nil?
        updated_one_day_reading.set_type('CMPH')
        @amr_data.add(date, updated_one_day_reading.deep_dup)
      else
        logger.debug "Unable to override partial/missing data for #{@meter.mpan_mprn} on #{date}"
      end
    end
  end

  def remove_readings_with_too_many_missing_partial_readings(max_missing_readings, missing_data_value)
    missing_dates = []
    (@amr_data.start_date..@amr_data.end_date).each do |date|
      if @amr_data.date_exists?(date) && @amr_data.days_kwh_x48(date).count(missing_data_value) > max_missing_readings
        missing_dates.push(date)
      end
    end
    missing_dates.each do |date|
      @amr_data.delete(date)
    end
    missing_dates
  end

  def interpolate_zero_readings(days_kwh_x48, missing_data_value: 0.0)
    interpolation_data = {}

    days_kwh_x48.each_index do |halfhour_index|
      interpolation_data[halfhour_index] = days_kwh_x48[halfhour_index] if days_kwh_x48[halfhour_index] != missing_data_value
    end

    interpolation = Interpolate::Points.new(interpolation_data)

    days_kwh_x48.each_index do |halfhour_index|
      days_kwh_x48[halfhour_index] = interpolation.at(halfhour_index) if days_kwh_x48[halfhour_index] == missing_data_value
    end

    days_kwh_x48
  end

  def set_missing_data_to_zero_on_heating_meter_during_summer(start_toy, end_toy)
    logger.info "Setting missing data to zero between #{start_toy} and #{end_toy}"
    set_all_missing_data_to_zero_by_time_of_year(start_toy, end_toy, 'SUMZ')
  end

  def set_all_missing_data_to_zero
    logger.info "Setting all missing data to zero"
    start_toy = TimeOfYear.new(1, 1) # 1st Jan
    end_toy = TimeOfYear.new(12, 31) # 31st Dec
    set_all_missing_data_to_zero_by_time_of_year(start_toy, end_toy, 'ALLZ')
  end

  # typically is imperial to metric meter readings aren't corrected to kWh properly at source
  def scale_amr_data(start_date, end_date, scale)
    logger.info "Rescaling data between #{start_date} and #{end_date} by #{scale}"
    start_date = @amr_data.start_date if @amr_data.start_date > start_date # case where another correction has changed data prior to confiured correction
    (start_date..end_date).each do |date|
      if @amr_data.date_exists?(date) && @amr_data.substitution_type(date) != 'S31M'
        new_data_x48 = []
        (0..47).each do |halfhour_index|
          new_data_x48.push(@amr_data.kwh(date, halfhour_index) * scale)
        end
        scaled_data = OneDayAMRReading.new(meter_id, date, 'S31M', nil, DateTime.now, new_data_x48)
        @amr_data.add(date, scaled_data)
      end
    end
  end

  def correct_holidays_with_adjacent_academic_years
    missing_holiday_dates = []
    (@amr_data.start_date..@amr_data.end_date).each do |date|
      missing_holiday_dates.push(date) if @amr_data.date_missing?(date) && @holidays.holiday?(date)
    end

    missing_holiday_dates.each do |date|
      begin
        holiday_type = @holidays.type(date)

        matching_holidays = list_of_similar_holidays(date, holiday_type)
        if matching_holidays.empty?
          logger.info "Unable to find substitute matching holiday for date #{date}"
        else
          adjusted_date = find_matching_holiday_day(@amr_data, matching_holidays, date.wday)

          unless adjusted_date.nil?
            if @meter.meter_type == :electricity
              logger.debug "Correcting missing electricity holiday on #{date} with data from #{adjusted_date}"
              substituted_electricity_holiday_data = OneDayAMRReading.new(meter_id, date, 'ESBH', adjusted_date, DateTime.now, @amr_data[adjusted_date].kwh_data_x48)
              @amr_data.add(date, substituted_electricity_holiday_data)
            elsif @meter.meter_type == :gas
              # perhaps would be better if substitute similar weekday had matching temperatures?
              # probably better this way if thermally massive building?
              substitute_gas_data = adjusted_substitute_heating_kwh(date, adjusted_date)
              substituted_gas_holiday_data = OneDayAMRReading.new(meter_id, date, 'GSBH', adjusted_date, DateTime.now, substitute_gas_data)
              @amr_data.add(date, substituted_gas_holiday_data)
            end
          else
            zero_kwh_readings = Array.new(48, 0.0)
            type = @meter.meter_type == @gas ? 'G0H1' : 'E0H1'
            zero_gas_holiday_data = OneDayAMRReading.new(meter_id, date, type, adjusted_date, DateTime.now, zero_kwh_readings)
            @amr_data.add(date, zero_gas_holiday_data) # have to assume if no replacement holiday reading gas was completely off
          end
        end
      rescue EnergySparksUnexpectedStateException => e
        logger.error "Comment: deliberately rescued missing holiday data exception for date #{date}"
        logger.error e.message
      end
    end
  end

  def find_matching_holiday_day(amr_data, list_of_holidays, day_of_week)
    list_of_holidays.each do |holiday_period|
      (holiday_period.start_date..holiday_period.end_date).each do |date|
        return date if date.wday == day_of_week && amr_data.date_exists?(date)
      end
    end
    nil
  end

  def list_of_similar_holidays(date, holiday_type)
    list_of_matching_holidays = []
    (1..3).each do |year_offset|
      hol = similar_holiday(date, holiday_type, year_offset) # forward N years
      list_of_matching_holidays.push(hol) unless hol.nil?
      hol = similar_holiday(date, holiday_type, -1 * year_offset) # back N years
      list_of_matching_holidays.push(hol) unless hol.nil?
    end
    list_of_matching_holidays
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
          return hols
        end
      else
        return nil
      end
    end
  end

  def final_missing_data_set_to_small_negative
    missing_dates = []
    (@amr_data.start_date..@amr_data.end_date).each do |date|
      if @amr_data.date_missing?(date)
        missing_dates.push(date)
      end
    end
    missing_dates.each do |date|
      no_data = Array.new(48, 0.0123456)
      dummy_data = OneDayAMRReading.new(meter_id, date, 'PROB', nil, DateTime.now, no_data)
      @amr_data.add(date, dummy_data)
    end
  end

  def replace_missing_weekend_data_with_zero
    replaced_dates = []
    (@amr_data.start_date..@amr_data.end_date).each do |date|
      if DateTimeHelper.weekend?(date) && @amr_data.date_missing?(date)
        replaced_dates.push(date)
        zero_data = Array.new(48, 0.0)
        missing_weekend_data = OneDayAMRReading.new(meter_id, date, 'MWKE', nil, DateTime.now, zero_data)
        @amr_data.add(date, missing_weekend_data)
      end
    end
  end

  def replace_missing_data_with_zero(start_date, end_date)
    logger.info "Replacing missing data between #{start_date} and #{end_date} with zero"
    replaced_dates = []
    start_date = start_date.nil? ? @amr_data.start_date : start_date
    end_date = end_date.nil? ? @amr_data.end_date : end_date
    (start_date..end_date).each do |date|
      if @amr_data.date_missing?(date)
        replaced_dates.push(date)
        zero_data = Array.new(48, 0.0)
        missing_data_zero_in_date_range = OneDayAMRReading.new(meter_id, date, 'MDTZ', nil, DateTime.now, zero_data)
        @amr_data.add(date, missing_data_zero_in_date_range)
      end
    end
  end

  def zero_data_in_date_range(start_date, end_date)
    logger.info "Overwriting bad data between #{start_date} and #{end_date} with zero"
    (start_date..end_date).each do |date|
      if @amr_data.date_exists?(date)
        zero_data = Array.new(48, 0.0)
        zero_data_day = OneDayAMRReading.new(meter_id, date, 'ZDTR', nil, DateTime.now, zero_data)
        @amr_data.add(date, zero_data_day)
      end
    end
  end

  def zero_missing_data_in_date_range(start_date, end_date)
    logger.info "Setting missing data between #{start_date} and #{end_date} to zero"
    (start_date..end_date).each do |date|
      if @amr_data.date_missing?(date)
        zero_data = Array.new(48, 0.0)
        zero_data_day = OneDayAMRReading.new(meter_id, date, 'ZMDR', nil, DateTime.now, zero_data)
        @amr_data.add(date, zero_data_day)
      end
    end
  end

  def override_with_sheffield_solar_pv_data(start_date, end_date)
    raise EnergySparksMeterSpecification, "Unable to correct pv data, wrong meter type #{@meter.meter_type}" if @meter.meter_type != :solar_pv
    sd = [start_date, @meter.amr_data.start_date].max
    ed = [end_date,   @meter.amr_data.end_date  ].min
    existing_kwh = sd <= ed ? @meter.amr_data.kwh_date_range(sd, ed) : 0.0
    logger.info "Correcting solar pv production data using Sheffield #{start_date} to #{end_date} current total kwh #{existing_kwh}"
    pv = SolarPVPanels.new(@meter.attributes(:solar_pv), @meter.meter_collection.solar_pv)
    (start_date..end_date).each do |date|
      pv_days_readings = pv.days_pv(date, @meter.solar_pv)
      @amr_data.add(date, pv_days_readings)
    end
    updated_kwh = @meter.amr_data.kwh_date_range(start_date, end_date)
    logger.info "Updated sheffield pv data kwh = #{updated_kwh}"
  end

  def in_meter_correction_period?(date)
    @meter.meter_correction_rules.each do |rule|
      if rule.is_a?(Hash) && rule.key?(:auto_insert_missing_readings) &&
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
    gap_count = 0
    first_bad_date = Date.new(2050, 1, 1)
    (@amr_data.start_date..@amr_data.end_date).reverse_each do |date|
      if @amr_data.date_missing?(date)
        first_bad_date = date if gap_count.zero?
        gap_count += 1
      else
        gap_count = 0
      end
      if gap_count > @max_days_missing_data && !in_meter_correction_period?(date)
        min_date = first_bad_date + 1
        @amr_data.set_start_date(min_date)
        msg =  'Ignoring all data before ' + min_date.strftime(FSTRDEF)
        msg += ' as gap of more than ' + @max_days_missing_data.to_s + ' days '
        msg += (@amr_data.keys.index(min_date) - 1).to_s + ' days of data ignored'
        logger.info msg
        substitute_data = Array.new(48, 0.0)
        @amr_data.add(min_date, OneDayAMRReading.new(meter_id, min_date, 'LGAP', nil, DateTime.now, substitute_data))
        break
      end
    end
  end

  def fill_in_missing_data(sd = @amr_data.start_date, ed = @amr_data.end_date, sub_type_code = 'S', override = false)
    missing_days = {}
    (sd..ed).each do |date|
      if @amr_data.date_missing?(date) || override
        if @meter.meter_type == :electricity
          missing_days[date] = substitute_missing_electricity_data(date, sub_type_code)
        elsif @meter.meter_type == :gas
          missing_days[date] = substitute_missing_gas_data(date, sub_type_code)
        end
      end
    end

    list_of_date_substitutions = []
    missing_days.each do |date, corrected_data|
      unless corrected_data.nil?
        substitute_date, substitute_data = corrected_data
        @amr_data.add(date, substitute_data) unless substitute_data.nil? # TODO(PH) - handle nil? test by correction
      end
    end
  end

  def substitute_missing_electricity_data(date, sub_type_code)
    substitute_missing_data(date, sub_type_code, 'E')
  end

  # iterate out from missing data date, looking for a similar day without missing data
  def substitute_missing_data(date, sub_type_code, fuel_code)
    missing_daytype = daytype(date)
    alternating_search_days_offset.each do |days_offset|
      substitute_date = date + days_offset
      if @amr_data.date_exists?(substitute_date) && daytype(substitute_date) == missing_daytype
        return [date, create_substituted_data(date, substitute_date, sub_type_code, fuel_code)]
      end
    end
    [date, nil]
  end

  # [1, -1, 2, -2 etc.]
  def alternating_search_days_offset
    max_days = MAXSEARCHRANGEFORCORRECTEDDATA
    @alternating_search_days_offset ||= (1..max_days).to_a.zip((-max_days..-1).to_a.reverse).flatten
  end
  
  def substitute_missing_gas_data(date, sub_type_code)
    heating_on = heating_model.heat_on_missing_data?(date) if heating_model != NO_MODEL
    missing_daytype = daytype(date)
    avg_temperature = average_temperature(date)

    alternating_search_days_offset.each do |days_offset|
      substitute_date = date + days_offset
      if @amr_data.date_exists?(substitute_date)
        substitute_day_temperature = average_temperature(substitute_date)
        if heating_model == NO_MODEL
          if @amr_data.date_exists?(substitute_date) && daytype(substitute_date) == missing_daytype
           return [date, create_substituted_data(date, substitute_date, sub_type_code, 'G')]
          end
        elsif heating_on == heating_model.heat_on_missing_data?(substitute_date) &&
           within_temperature_range?(avg_temperature, substitute_day_temperature) &&
           daytype(substitute_date) == missing_daytype
          return [date, create_substituted_gas_data(date, substitute_date, sub_type_code)]
        end
      end
    end
    logger.debug "Error: Unable to find suitable substitute for missing day of gas data #{date} temperature #{avg_temperature.round(0)} daytype #{missing_daytype} heating? #{heating_on}"
    [date, nil]
  end

  # iterate put from missing data, looking for a similar day without missing data
  # then adjust for temperature
  def substitute_missing_gas_data_deprecated(date, sub_type_code)
    heating_on = heating_model.heat_on_missing_data?(date)
    missing_daytype = daytype(date)
    avg_temperature = average_temperature(date)

    (1..MAXSEARCHRANGEFORCORRECTEDDATA).each do |days_offset|
      # look for similar day after the missing date
      day_after = date + days_offset

      if day_after <= @amr_data.end_date && @amr_data.date_exists?(day_after)
        temperature_after = average_temperature(day_after)
        if heating_on == heating_model.heat_on_missing_data?(day_after) &&
            within_temperature_range?(avg_temperature, temperature_after) &&
            daytype(day_after) == missing_daytype
          return [date, create_substituted_gas_data(date, day_after, sub_type_code)]
        end
      end
      # look for similar day before the missing date
      day_before = date - days_offset
      temperature_before = average_temperature(day_before)
      if day_before >= @amr_data.start_date &&
          @amr_data.date_exists?(day_before) &&
          heating_on == heating_model.heat_on_missing_data?(day_before) &&
          within_temperature_range?(avg_temperature, temperature_before) &&
          daytype(day_before) == missing_daytype
        return [date, create_substituted_gas_data(date, day_before, sub_type_code)]
      end
    end
    logger.debug "Error: Unable to find suitable substitute for missing day of gas data #{date} temperature #{avg_temperature.round(0)} daytype #{missing_daytype} heating? #{heating_on}"
    [date, nil]
  end

  def create_substituted_gas_data(date, adjusted_date, sub_type_code)
    amr_day_type = day_type_to_amr_type_letter(daytype(date))
    sub_type = 'G' + sub_type_code + amr_day_type + '1'
    adjusted_data = adjusted_substitute_heating_kwh(date, adjusted_date)
    OneDayAMRReading.new(meter_id, date, sub_type, adjusted_date, DateTime.now, adjusted_data)
  end

  def create_substituted_data(date, adjusted_date, sub_type_code, fuel_code)
    amr_day_type = day_type_to_amr_type_letter(daytype(date))
    sub_type = fuel_code  + sub_type_code + amr_day_type + '1'
    substitute_data = @amr_data.days_kwh_x48(adjusted_date).deep_dup
    OneDayAMRReading.new(meter_id, date, sub_type, adjusted_date, DateTime.now, substitute_data)
  end

  def average_temperature(date)
    @average_temperatures ||= {}
    begin
      @average_temperatures[date] ||= @temperatures.average_temperature(date)
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
    kwh_prediction_for_missing_day = heating_model.predicted_kwh(missing_day, @temperatures.average_temperature(missing_day), substitute_day)
    kwh_prediction_for_substitute_day = heating_model.predicted_kwh(substitute_day, @temperatures.average_temperature(substitute_day))

    # using an adjustment of kWhs * (A + BTm)/(A + BTs), an alternative could be kWhs + B(Tm - Ts)
    prediction_ratio = kwh_prediction_for_missing_day / kwh_prediction_for_substitute_day
    if prediction_ratio < 0
      logger.debug "Warning: negative predicated data for missing day #{missing_day} from #{substitute_day} setting to zero"
      prediction_ratio = 0.0
    end

    if kwh_prediction_for_substitute_day == 0.0
      logger.warn "Warning: zero predicted kwh for substitute day #{substitute_day} setting prediction_ratio to 0.0 for #{missing_day}"
      prediction_ratio = 1.0
    end

    prediction_ratio = 1.0 if kwh_prediction_for_substitute_day == 0.0 && kwh_prediction_for_missing_day == 0.0

    substitute_data = Array.new(48, 0.0)
    (0..47).each do |halfhour_index|
      substitute_data[halfhour_index] = @amr_data.kwh(substitute_day, halfhour_index) * prediction_ratio
    end
    substitute_data
  end

  def create_heating_model
    begin
      @model_cache = AnalyseHeatingAndHotWater::ModelCache.new(@meter)
      period_of_all_meter_readings = SchoolDatePeriod.new(:validation, 'Validation Period', @amr_data.start_date, @amr_data.end_date)
      @model_cache.create_and_fit_model(:best, period_of_all_meter_readings, true)
    rescue EnergySparksNotEnoughDataException => e
      logger.info "Unable to calculate model data for heat day substitution for #{@meter.mpan_mprn}"
      logger.info e.message
      logger.info 'using simplistic substitution without modelling'
      NO_MODEL
    end
  end

  def daytype(date)
    if @holidays.holiday?(date)
      weekend?(date) ? :holidayandweekend : :holidayweekday
    else
      weekend?(date) ? :weekend : :weekday
    end
  end

  def day_type_to_amr_type_letter(daytype)
    case daytype
    when :holidayandweekend
      return 'h'
    when :holidayweekday
      return 'H'
    when :weekend
      return 'W'
    when :weekday
      return 'S'
    else
      raise EnergySparksUnexpectedStateException.new('Unexpected day type')
    end
  end

  def weekend?(date)
    date.sunday? || date.saturday?
  end

  def no_readings?
    @amr_data.nil? || @amr_data.days == 0
  end

  def check_temperature_data_covers_gas_meter_data_range
    return if @meter.fuel_type != :gas # no storage_heater as they are created later by the aggregation service
    return if no_readings?

    raise NotEnoughTemperaturedata, "Nil or empty temperature data for meter #{@meter.mpxn} #{@meter.fuel_type}" if @temperatures.nil? || @temperatures.empty?

    if @temperatures.start_date > @amr_data.start_date || @temperatures.end_date < @amr_data.end_date
      raise NotEnoughTemperaturedata, "Temperature data from #{@temperatures.start_date} to #{@temperatures.end_date} doesnt cover period of #{@meter.mpxn} #{@meter.fuel_type} meter data from #{@amr_data.start_date} to #{@amr_data.end_date}"
    end
  end
end
