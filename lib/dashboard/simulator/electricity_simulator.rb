class ElectricitySimulator
  OUTSIDE_TEMPERATURE_FOR_CALCULATED_HEATING_PERIOD = 11
  include Logging

  attr_reader :period, :holidays, :temperatures, :total, :appliance_definitions
  attr_reader :calc_components_results, :solar_irradiation, :school, :existing_electricity_meter
  def initialize(school)
    electricity_meter_data = school.aggregated_electricity_meters.amr_data
    @existing_electricity_meter = school.aggregated_electricity_meters
    @holidays = school.holidays
    @period = @holidays.years_to_date(electricity_meter_data.start_date, electricity_meter_data.end_date, false)[0]
    @temperatures = school.temperatures
    @solar_irradiation = school.solar_irradiation
    @solar_pv = school.solar_pv
    @school = school
    calculate_heating_periods
    @calc_components_results = {}

    logger.info "Initialise simulator for period: #{electricity_meter_data.start_date} and end date: #{electricity_meter_data.end_date}"
  end

  # fit default parameters to actual AMR data
  def fit
    # TODO(PH,21Jul2018):
    # Fit baseload fn(school size) => server usage, remainder unaccounted for baseload, some hot water, other standby
    # Fit lighting: min lumens/watt 45, any winter excess assumed to be electrical heating
    # Fit kitchen: excess morning usage
    # Fit hot water: check for summer gas usage, define any underspend as electric
    # Fit security lighting: weekend additional overnight usage (adjust unaccounted for baseload down (? - depends on whether use stat algorithm)
    # Fit solar pv: only if zero summer weekend usage?
  end

  def calculate_heating_periods
    if @school.aggregated_heat_meters.nil?
      calculate_heating_periods_from_temperatures
    else
      calculate_model
    end
  end

  def heating_on?(date)
    if @school.aggregated_heat_meters.nil?
      @calculated_heating_dates.key?(date)
    else
      @heating_model.heating_on?(date)
    end
  end

  # calculate heating periods on the basis of temperature in the abscence of a heating meter
  def calculate_heating_periods_from_temperatures
    @calculated_heating_dates = {}
    sunday = DateTimeHelper::next_weekday(@period.start_date, 0)

    while sunday + 7 < @existing_electricity_meter.amr_data.end_date
      temp = @school.temperatures.average_temperature_in_date_range(sunday, sunday + 6)

      if temp.nil?
        logger.warn "Temp is nil for #{sunday} to #{sunday + 6}"
      elsif temp < OUTSIDE_TEMPERATURE_FOR_CALCULATED_HEATING_PERIOD
        (sunday..sunday+6).each do |date|
          @calculated_heating_dates[date] = true
        end
      end
      sunday += 7
    end
  end

  def calculate_model
    # TODO(PH,21Jul2018): should really check heating meter data up to date as electrical meter data
    start_date = @school.aggregated_heat_meters.amr_data.start_date
    end_date = @school.aggregated_heat_meters.amr_data.end_date
    periods = @school.holidays.years_to_date(start_date, end_date, false)
    @heating_model = @school.heating_model(periods[0])
    @heating_model.calculate_heating_periods(start_date, end_date)
  end

  def simulate(appliance_definitions)
    @appliance_definitions = appliance_definitions
    logger.debug appliance_definitions.inspect
    @total = empty_amr_data_set('Simulator Totals')
    total_amr_data = nil
# rubocop:disable all
    time = Benchmark.measure {
      logger.info 'lighting'
      logger.info Benchmark.measure { simulate_lighting }
      logger.info 'ict'
      logger.info Benchmark.measure { simulate_ict }
      logger.info 'boiler pump'
      logger.info Benchmark.measure { simulate_boiler_pump }
      logger.info 'security lighting'
      logger.info Benchmark.measure { simulate_security_lighting }
      logger.info 'kitchen'
      logger.info Benchmark.measure { simulate_kitchen }
      logger.info 'hot water'
      logger.info Benchmark.measure { simulate_hot_water }
      logger.info 'air con'
      logger.info Benchmark.measure { simulate_air_con }
      logger.info 'flood lighting'
      logger.info Benchmark.measure { simulate_flood_lighting }
      logger.info 'electrical heating'
      logger.info Benchmark.measure { simulate_electrical_heating }
      logger.info 'unaccounted for baseload'
      logger.info Benchmark.measure { simulate_unaccounted_for_baseload }
      logger.info 'solar pv'
      logger.info Benchmark.measure { simulate_solar_pv }
      logger.info 'aggregate results'
      logger.info Benchmark.measure { total_amr_data = aggregate_results }
    }
# rubocop:enable all
    logger.info "Overall time #{time}"

    @school.electricity_simulation_meter = create_meters(total_amr_data)
  end

  def empty_amr_data_set(type)
    AMRData.create_empty_dataset(type, @period.start_date, @period.end_date)
  end

  def default_simulator_parameters
    definitions = ElectricitySimulatorConfiguration::APPLIANCE_DEFINITIONS.deep_dup
    definitions[:unaccounted_for_baseload][:baseload] = (school.floor_area / 1_000.0) * 0.5 # 1 single number - useful
    definitions
  end

  def create_empty_amr_data(type)
    data = AMRData.new(type)
    (period.start_date..period.end_date).each do |date|
      data.add(date, Array.new(48, 0.0))
    end
    logger.debug "Creating empty #{type} simulator data, #{data.length} elements"
    data
  end

  def create_meters(total_amr_data)
    electricity_simulation_meter = create_new_meter(total_amr_data, :electricity, 'sim 1', 'Electrical Simulator')
    @calc_components_results.reverse_each do |key, value| # reverse as improves bar chart breakdown order a little
      meter = create_new_meter(value, :electricity, key, key)
      electricity_simulation_meter.sub_meters.push(meter)
    end
    logger.debug "Created #{electricity_simulation_meter.sub_meters.length} sub meters"
    electricity_simulation_meter
  end

  def create_new_meter(amr_data, type, identifier, name)
    MeterAnalysis.new(
      @existing_electricity_meter,
      amr_data,
      type,
      identifier,
      name,
      @existing_electricity_meter.floor_area,
      @existing_electricity_meter.number_of_pupils,
      @existing_electricity_meter.solar_pv_installation,
      @existing_electricity_meter.storage_heater_config
    )
  end

  def aggregate_results
    logger.debug "Aggregating results"
    totals = empty_amr_data_set("Totals")
    @calc_components_results.each do |key, value|
      (totals.start_date..totals.end_date).each do |date|
        totals[date] = [totals[date], value[date]].transpose.map(&:sum)
      end
      sub_total = component_total(value)
      logger.debug "Component #{key} = #{sub_total} k_wh"
    end
    total_total = component_total(totals)
    logger.debug "Total simulation #{total_total}  kwh"
    totals
  end

  def component_total(component)
    total = 0.0
    (component.start_date..component.end_date).each do |date|
      total += component[date].inject(:+)
    end
    total
  end

  #=======================================================================================================================================================================
  # LIGHTING SIMULATION
  #  - is a function of occupancy * external anbient lighting * peak power (which is itself a function of the lighting efficacy (efficiency of lighting * its brightness (per floor area) * the floor area )
  def simulate_lighting
    lighting_data = empty_amr_data_set("Lighting")

    peak_power =  @appliance_definitions[:lighting][:lumens_per_m2] * school.floor_area / 1000 / @appliance_definitions[:lighting][:lumens_per_watt]

    @cache_irradiance_for_speed = nil
    (lighting_data.start_date..lighting_data.end_date).each do |date|
      (0..47).each do |half_hour_index|
        if !@holidays.holiday?(date) && !weekend?(date)

          solar_insol = @solar_irradiation.solar_irradiance(date, half_hour_index)
          percent_of_peak = interpolate_y_value(@appliance_definitions[:lighting][:percent_on_as_function_of_solar_irradiance][:solar_irradiance],
                          @appliance_definitions[:lighting][:percent_on_as_function_of_solar_irradiance][:percent_of_peak],
                          solar_insol)

          occupancy = @appliance_definitions[:lighting][:occupancy_by_half_hour][half_hour_index]

          power = peak_power * percent_of_peak * occupancy

          lighting_data[date][half_hour_index] = power * 0.5 # # power kW to 1/2 hour k_wh

        end
      end
    end
    component_total(lighting_data)
    @calc_components_results["Lighting"] = lighting_data
  end

  # converts from 2 arrays of floats/fixed representing the x and y axis to a hash of points ( x >= y) for compatibility by the Interpolate gem
  def interpolate_y_value(xarr, yarr, x_value)
    if @cache_irradiance_for_speed.nil?
      points = {}
      count = 0
      xarr.each do |x|
        points[x] = yarr[count]
        count += 1
      end

      @cache_irradiance_for_speed = Interpolate::Points.new(points)
    end
    @cache_irradiance_for_speed.at(x_value)
  end

  #=======================================================================================================================================================================
  # ICT SIMULATION
  #  - note this unlike the other appliance simulators produces 3 data sets - 1 for each type of server, desktop and laptop - i_pad/tablets are ignored as very low k_wh, but can be included a a laptop
  def simulate_ict
    server_data = empty_amr_data_set(:servers)
    desktop_data = empty_amr_data_set(:desktops)
    laptop_data = empty_amr_data_set(:laptops)

    @appliance_definitions[:ict].each_value do |ict_appliance_group|
      next unless ict_appliance_group.instance_of? Hash
      (server_data.start_date..server_data.end_date).each do |date| # arbitrary use the date list for te servers to iterate on, but the inner work applies via the case statement to desktops or laptops
        on_today = !(@holidays.holiday?(date) && ict_appliance_group.key?(:holidays) && !ict_appliance_group[:holidays])
        on_today &&= !(weekend?(date) && ict_appliance_group.key?(:weekends) && !ict_appliance_group[:weekends])
        (0..47).each do |half_hour_index|
          if on_today
            if ict_appliance_group.key?(:usage_percent_by_time_of_day)
              percent_on = ict_appliance_group[:usage_percent_by_time_of_day][half_hour_index]
              power = percent_on * ict_appliance_group[:number] * ict_appliance_group[:power_watts_each] / 1000.0
              power += (1 - percent_on) * ict_appliance_group[:number] * ict_appliance_group[:standby_watts_each] / 1000.0
            else
              power = ict_appliance_group[:number] * ict_appliance_group[:power_watts_each] / 1000.0
            end

            case ict_appliance_group[:type]
            when 'server', :server
              server_data[date][half_hour_index] += power / 2 # power kW to 1/2 hour k_wh
            when 'desktop', :desktop
              desktop_data[date][half_hour_index] += power / 2 # power kW to 1/2 hour k_wh
            when 'laptop', :laptop
              laptop_data[date][half_hour_index] += power / 2 # power kW to 1/2 hour k_wh
            end
          end
        end
      end
    end

    @calc_components_results['Servers'] = server_data
    @calc_components_results['Desktops'] = desktop_data
    @calc_components_results['Laptops'] = laptop_data
  end

  #=======================================================================================================================================================================
  # BOILER PUMP SIMULATION

  def simulate_boiler_pump
    if @school.aggregated_heat_meters.nil?
      simulate_boiler_pump_using_manual_simulator_configuration
    else
      simulate_boiler_pump_using_gas_data
    end
  end

  def simulate_boiler_pump_using_manual_simulator_configuration
    boiler_pump_data = empty_amr_data_set("Boiler Pumps")

    pump_power = @appliance_definitions[:boiler_pumps][:pump_power]
    heating_on_during_weekends = @appliance_definitions[:boiler_pumps][:weekends]
    heating_on_during_holidays = @appliance_definitions[:boiler_pumps][:holidays]

    (boiler_pump_data.start_date..boiler_pump_data.end_date).each do |date|
      heating_on = heating_on?(date) && !(@holidays.holiday?(date) && !heating_on_during_holidays) && !(weekend?(date) && !heating_on_during_weekends)
      if heating_on
        (0..47).each do |half_hour_index|
          amr_bucket_start_time = convert_half_hour_index_to_time(half_hour_index)
          amr_bucket_end_time = convert_half_hour_index_to_time(half_hour_index + 1)

          # fractionally calculate overlap to get correct k_wh on non-half hour boundary overlap
          overlap = hours_overlap_between_two_time_ranges(amr_bucket_start_time, amr_bucket_end_time, @appliance_definitions[:boiler_pumps][:start_time], @appliance_definitions[:boiler_pumps][:end_time])

          frost_protect_temp = @appliance_definitions[:boiler_pumps][:frost_protection_temp]

          # to cope with the fractional half hour case if the heating isn;t on for the full fraction of the half hour, then replace if frost protection
          # 0.5 hour period if frost protection required - in an ideal world the frost protection setting would be further interpolated by the temperatures at
          # the start and end of each bucket, to get an more accurate intercept, however this is moot given we are ignoring thermal mass

          if overlap > 0.5 && @temperatures.temperature(date, half_hour_index) <= frost_protect_temp
            overlap = 0.5 # i.e. half and hour
          end

          boiler_pump_data[date][half_hour_index] = pump_power * overlap # automatically in k_wh as conversion kW * time in hours
        end
      end
    end
    @calc_components_results["Boiler Pumps"] = boiler_pump_data
  end

  def simulate_boiler_pump_using_gas_data
    boiler_pump_data = empty_amr_data_set("Boiler Pumps")
    pump_power = @appliance_definitions[:boiler_pumps][:pump_power]
    (boiler_pump_data.start_date..boiler_pump_data.end_date).each do |date|
      if @school.aggregated_heat_meters.amr_data.key?(date)
        (0..47).each do |half_hour_index|
          amr_gas_usage = @school.aggregated_heat_meters.amr_data.kwh(date,half_hour_index) || 0.0
          gas_power_consumption = amr_gas_usage * 2.0
          boiler_pump_data[date][half_hour_index] = pump_power / 2.0 if (gas_power_consumption > 15.0)
        end
      end
    end
    @calc_components_results["Boiler Pumps"] = boiler_pump_data
  end

  def weekend?(date)
    date.saturday? || date.sunday?
  end

  def in_heating_season(start_dates, end_dates, date)
    count = 0
    start_dates.each do |start_date|
      end_date = end_dates[count]

      if date >= start_date && date <= end_date
        return true
      end
      count += 1
    end

    false
  end

  def convert_time_to_half_hour_index(time)
    hour = time.hour.to_i
    half_hour_index = time.min >= 30
    hour * 2 + (half_hour_index ? 1 : 0).to_i
  end

  #=======================================================================================================================================================================
  # SECURITY LIGHTING SIMULATION
  def simulate_security_lighting
    lighting_data = empty_amr_data_set("Security Lighting")

    power = @appliance_definitions[:security_lighting][:power]

    if power >= 0.0
      control_type = @appliance_definitions[:security_lighting][:control_type].first

      midnight0 = convert_half_hour_index_to_time(0)
      midnight24 = convert_half_hour_index_to_time(48)

      logger.debug "control type #{control_type}"
      case control_type
      when :sunrise_sunset
        (lighting_data.start_date..lighting_data.end_date).each do |date|
          month = date.month - 1
          sunrise_str = @appliance_definitions[:security_lighting][:sunrise_times][month]
          sunset_str = @appliance_definitions[:security_lighting][:sunset_times][month]

          sunrise = convert_time_string_to_time(sunrise_str)
          sunset = convert_time_string_to_time(sunset_str)

          (0..47).each do |half_hour_index|
            amr_bucket_start_time = convert_half_hour_index_to_time(half_hour_index)
            amr_bucket_end_time = convert_half_hour_index_to_time(half_hour_index + 1)

            # fractionally calculate overlap to get correct k_wh on non-half hour boundary overlap
            overlap = hours_overlap_between_two_time_ranges(amr_bucket_start_time, amr_bucket_end_time, midnight0, sunrise)
            overlap += hours_overlap_between_two_time_ranges(amr_bucket_start_time, amr_bucket_end_time, sunset, midnight24)

            lighting_data[date][half_hour_index] += power * overlap # automatically in k_wh as conversion kW * time in hours
          end
        end
      when :ambient
        (lighting_data.start_date..lighting_data.end_date).each do |date|
          (0..47).each do |half_hour_index|
            solar_insol = @solar_irradiation.irradiance(date, half_hour_index)
            if solar_insol < @appliance_definitions[:security_lighting][:ambient_threshold]
              lighting_data[date][half_hour_index] += power / 2 # power kW to 1/2 hour k_wh
            end
          end
        end
      when :fixed_times # note the end time is early morning, so less than the start time which is early evening
        fixed_start_time_string = @appliance_definitions[:security_lighting][:fixed_start_time]
        starttime = convert_time_string_to_time(fixed_start_time_string)
        fixed_end_time_string = @appliance_definitions[:security_lighting][:fixed_end_time]
        endtime = convert_time_string_to_time(fixed_end_time_string)

        (lighting_data.start_date..lighting_data.end_date).each do |date|
          (0..47).each do |half_hour_index|
            amr_bucket_start_time = convert_half_hour_index_to_time(half_hour_index)
            amr_bucket_end_time = convert_half_hour_index_to_time(half_hour_index + 1)

            # fractionally calculate overlap to get correct k_wh on non-half hour boundary overlap
            overlap = hours_overlap_between_two_time_ranges(amr_bucket_start_time, amr_bucket_end_time, midnight0, endtime)
            overlap += hours_overlap_between_two_time_ranges(amr_bucket_start_time, amr_bucket_end_time, starttime, midnight24)

            lighting_data[date][half_hour_index] += power * overlap # automatically in k_wh as conversion kW * time in hours
          end
        end
      else
        raise Not_implemented_error.new("Simulator Security Light Control Type" << control_type)
      end
    end
    @calc_components_results["Security Lighting"] = lighting_data
  end

  def convert_time_string_to_time(time_str)
    TimeOfDay.new(time_str[0, 2].to_i, time_str[3, 2].to_i)
  end

  def hours_overlap_between_two_time_ranges(start_time1, end_time1, start_time2, end_time2)
    if !start_time1.is_a?(TimeOfDay) || !end_time1.is_a?(TimeOfDay) || !start_time2.is_a?(TimeOfDay) || !end_time2.is_a?(TimeOfDay)
      raise EnergySparksUnexpectedStateException.new("Not all parameters of overlap calculations are TimeOfDay")
    end
    overlap = 0.0
    if end_time1 < start_time2 || start_time1 > end_time2 # no overlap
      return 0.0
    elsif start_time1 <= start_time2 && end_time1 <= end_time2 # range 1 starts before range 2, but ends within range 2
      overlap = end_time1 - start_time2
    elsif start_time1 >= start_time2 && end_time1 <= end_time2 # range 1 completely within range 2
      overlap = end_time1 - start_time1
    elsif start_time1 >= start_time2 # range 1 starts within range2 and ends afterwards
      overlap = end_time2 - start_time1
    else
      return 0.0
    end
    overlap / 3600
  end

  def convert_half_hour_index_to_time(half_hour_index)
    @cached_time_convert ||= {}
    return @cached_time_convert[half_hour_index] if @cached_time_convert.key?(half_hour_index)
    hour = (half_hour_index / 2).floor.to_i
    mins = 30 * (half_hour_index.odd? ? 1 : 0)
    time = TimeOfDay.new(hour, mins)
    @cached_time_convert[half_hour_index] = time
  end
  #=======================================================================================================================================================================
  # KITCHEN SIMULATION

  def simulate_kitchen
    kitchen_data = empty_amr_data_set("Kitchen")

    power = @appliance_definitions[:kitchen][:power]

    start_time = @appliance_definitions[:kitchen][:start_time]
    end_time = @appliance_definitions[:kitchen][:end_time]

    (kitchen_data.start_date..kitchen_data.end_date).each do |date|
      (0..47).each do |half_hour_index|
        if !@holidays.holiday?(date) && !weekend?(date)

          amr_bucket_start_time = convert_half_hour_index_to_time(half_hour_index)
          amr_bucket_end_time = convert_half_hour_index_to_time(half_hour_index + 1)

          # fractionally calculate overlap to get correct k_wh on non-half hour boundary overlap
          overlap = hours_overlap_between_two_time_ranges(amr_bucket_start_time, amr_bucket_end_time, start_time, end_time)

          kitchen_data[date][half_hour_index] = power * overlap # automatically in k_wh as conversion kW * time in hours
        end
      end
    end
    @calc_components_results["Kitchen"] = kitchen_data
  end
  #=======================================================================================================================================================================
  # HOT WATER SIMULATION

  def simulate_hot_water
    hot_water_data = empty_amr_data_set("Hot Water")

    percent_of_pupils_using_hot_water = @appliance_definitions[:electric_hot_water][:percent_of_pupils]
    standby_power = @appliance_definitions[:electric_hot_water][:standby_power]
    pupils = school.number_of_pupils * percent_of_pupils_using_hot_water
    litres_per_day_for_school = pupils * @appliance_definitions[:electric_hot_water][:litres_per_day_per_pupil]
    delta_t = 38 - 15 # assumes hot water delievered at 38C from 15C water
    heat_capacityk_wh_per_day = litres_per_day_for_school * delta_t * 4.2 * 1000 / 3600000 # heat capacity of water 4.2J/g/K, 3600000J in a k_wh
    school_open_time_hours = (@appliance_definitions[:electric_hot_water][:end_time] - @appliance_definitions[:electric_hot_water][:start_time]) / 3600
    average_power = heat_capacityk_wh_per_day / school_open_time_hours

    start_time = @appliance_definitions[:electric_hot_water][:start_time]
    end_time = @appliance_definitions[:electric_hot_water][:end_time]

    (hot_water_data.start_date..hot_water_data.end_date).each do |date|
      (0..47).each do |half_hour_index|
        if !@holidays.holiday?(date) && !weekend?(date)

          amr_bucket_start_time = convert_half_hour_index_to_time(half_hour_index)
          amr_bucket_end_time = convert_half_hour_index_to_time(half_hour_index + 1)

          # fractionally calculate overlap to get correct k_wh on non-half hour boundary overlap
          overlap = hours_overlap_between_two_time_ranges(amr_bucket_start_time, amr_bucket_end_time, start_time, end_time)

          hot_water_data[date][half_hour_index] = average_power * overlap # automatically in k_wh as conversion kW * time in hours

          # standby power out of schools hours

          if overlap < 0.5
            hot_water_data[date][half_hour_index] += standby_power * (0.5 - overlap)
          end
        elsif weekend?(date) && @appliance_definitions[:electric_hot_water][:weekends]
          hot_water_data[date][half_hour_index] = standby_power * 0.5 # power kW to 1/2 hour k_wh
        elsif @holidays.holiday?(date) && @appliance_definitions[:electric_hot_water][:holidays]
          hot_water_data[date][half_hour_index] = standby_power * 0.5 # power kW to 1/2 hour k_wh
        end
      end
    end
    @calc_components_results["Hot Water"] = hot_water_data
  end

  #=======================================================================================================================================================================
  # ELECTRICAL HEATING
  def simulate_electrical_heating
    electric_heating_data = empty_amr_data_set('Electrical Heating')
    config = @appliance_definitions[:electrical_heating]

    (electric_heating_data.start_date..electric_heating_data.end_date).each do |date|
      if heating_on?(date) && !(@holidays.holiday?(date) && !config[:holidays]) && !(weekend?(date) && !config[:weekends])
        (0..47).each do |half_hour_index|
          power = config[:fixed_power]
          amr_bucket_start_time = convert_half_hour_index_to_time(half_hour_index)
          amr_bucket_end_time = convert_half_hour_index_to_time(half_hour_index + 1)

          overlap = hours_overlap_between_two_time_ranges(amr_bucket_start_time, amr_bucket_end_time, config[:start_time], config[:end_time])

          degree_days = @temperatures.degree_hour(date, half_hour_index, config[:balancepoint_temperature])
          if degree_days > 0
            heating_power = config[:power_per_degreeday] * degree_days
            power += heating_power
          end

          electric_heating_data[date][half_hour_index] += power * overlap # automatically in k_wh as conversion kW * time in hours
        end
      end
    end
    @calc_components_results['Electrical Heating'] = electric_heating_data
  end

  #=======================================================================================================================================================================
  # FLOOD LIGHTING
  def simulate_flood_lighting
    flood_lighting_data = empty_amr_data_set("Flood Lighting")
    config = @appliance_definitions[:flood_lighting]

    if config[:power] >= 0.0
      (flood_lighting_data.start_date..flood_lighting_data.end_date).each do |date|
        config[:bookings].each do |booking|
          time_of_year = TimeOfYear.new(date.month, date.day)
          if time_of_year_in_range(booking[:start_date], booking[:end_date], time_of_year)
            if booking[:weekday] == date.wday && (booking[:holidays] || !@school.holidays.holiday?(date))
              (0..47).each do |half_hour_index|
                irradiance = @solar_irradiation.irradiance(date, half_hour_index)
                if irradiance < config[:ambient_light_threshold]
                  overlap = hours_overlap_between_two_time_ranges(
                              convert_half_hour_index_to_time(half_hour_index),
                              convert_half_hour_index_to_time(half_hour_index + 1),
                              booking[:start_time],
                              booking[:end_time]
                  )
                  flood_lighting_data[date][half_hour_index] += config[:power] * overlap # overlap fn(T) so converts to kWh
                end
              end
            end
          end
        end
      end
    end

    @calc_components_results["Flood Lighting"] = flood_lighting_data
  end

  def time_of_year_in_range(r1, r2, toy)
     if r2 >= r1 # range starts and ends before Dec 31
      toy >= r1 && toy <= r2
     else # range starts before Dec 31 and ends after Dec 31
      toy >= r1 || toy <= r2
     end
  end


  #=======================================================================================================================================================================
  # SUMMER AIRCON SIMULATION
  def simulate_air_con
    air_con_data = empty_amr_data_set("Air Conditioning")

    # power_per_degree_day = @appliance_definitions[:summer_air_conn][:power_per_degreeday]
    # cooling_balance_point_temperature = @appliance_definitions[:summer_air_conn][:balance_point_temperature]

    cooling_on_during_weekends = @appliance_definitions[:summer_air_conn][:weekends]
    cooling_on_during_holidays = @appliance_definitions[:summer_air_conn][:holidays]

    base_temp = @appliance_definitions[:summer_air_conn][:balancepoint_temperature]

    logger.warn "In simulate air con, with start date: #{air_con_data.start_date} and end date #{air_con_data.end_date}"

    (air_con_data.start_date..air_con_data.end_date).each do |date|
      (0..47).each do |half_hour_index|
        if !(@holidays.holiday?(date) && !cooling_on_during_holidays) && !(weekend?(date) && !cooling_on_during_weekends)

          amr_bucket_start_time = convert_half_hour_index_to_time(half_hour_index)
          amr_bucket_end_time = convert_half_hour_index_to_time(half_hour_index + 1)

          overlap = hours_overlap_between_two_time_ranges(amr_bucket_start_time, amr_bucket_end_time, @appliance_definitions[:summer_air_conn][:start_time], @appliance_definitions[:summer_air_conn][:end_time])

          degree_days = @temperatures.cooling_degree_days_at_time(date, half_hour_index, base_temp)

          if degree_days > 0 # to speed up code

            power_by_degree_day = @appliance_definitions[:summer_air_conn][:power_per_degreeday]

            air_con_power = power_by_degree_day * degree_days

            air_con_data[date][half_hour_index] = air_con_power * overlap # automatically in k_wh as conversion kW * time in hours
          end
        end
      end
    end
    @calc_components_results["Air Conditioning"] = air_con_data
  end

  #=======================================================================================================================================================================
  # UNACCOUNTED FOR BASELOAD SIMULATION
  def simulate_unaccounted_for_baseload
    unaccounted_for_baseload_data = empty_amr_data_set("Unaccounted For Baseload")
    baseload = @appliance_definitions[:unaccounted_for_baseload][:baseload]

    (unaccounted_for_baseload_data.start_date..unaccounted_for_baseload_data.end_date).each do |date|
      (0..47).each do |half_hour_index|
        unaccounted_for_baseload_data[date][half_hour_index] = (baseload / 2) # power kW to 1/2 hour k_wh
      end
    end
    @calc_components_results["Unaccounted For Baseload"] = unaccounted_for_baseload_data
  end

  #=======================================================================================================================================================================
  # SOLAR PV
  def simulate_solar_pv
    solar_pv_data = empty_amr_data_set("Solar PV")
    kwp = @appliance_definitions[:solar_pv][:kwp]


    if kwp > 0.0
      (solar_pv_data.start_date..solar_pv_data.end_date).each do |date|
        (0..47).each do |half_hour_index|
          pv_yield = @solar_pv.solar_pv_yield(date, half_hour_index) || 0.0
          solar_pv_data[date][half_hour_index] = -1.0 * kwp * pv_yield
        end
      end
    end
    @calc_components_results["Solar PV"] = solar_pv_data
  end
  #=======================================================================================================================================================================
  # ANOTHER SIMULATION
end
