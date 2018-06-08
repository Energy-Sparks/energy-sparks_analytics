class ElectricitySimulator
  attr_reader :period, :holidays, :temperatures, :total, :appliance_definitions, :calc_components_results, :solar_insolence, :school
  def initialize(period, holidays, temperatures, solarinsolence, school)
    @period = period
    @holidays = holidays
    @temperatures = temperatures
    @solar_insolence = solarinsolence
    @school = school
    @calc_components_results = {}
  end

  def simulate(appliance_definitions)
    @appliance_definitions = appliance_definitions
    # puts appliance_definitions.inspect
    @total = create_emptyAMRData("Final Totals")
# rubocop:disable all
    time = Benchmark.measure {
      puts Benchmark.measure { simulate_lighting }
      puts Benchmark.measure { simulateICT }
      puts Benchmark.measure { simulate_boiler_pump }
      puts Benchmark.measure { simulate_security_lighting }
      puts Benchmark.measure { simulate_kitchen }
      puts Benchmark.measure { simulate_hot_water }
      puts Benchmark.measure { simulate_air_con }
      puts Benchmark.measure { simulate_unaccounted_for_baseload }
      puts Benchmark.measure { aggregate_results }
    }
# rubocop:enable all
    puts "Overall time #{time}"
  end

  def create_empty_amr_data(type)
    data = AMRData.new(type)
    (period.start_date..period.end_date).each do |date|
      data.add(date, Array.new(48, 0.0))
    end
    puts "Creating empty #{type} simulator data, #{data.length} elements"
    data
  end

  def aggregate_results
    puts "Aggregating results"
    totals = create_emptyAMRData("Totals")
    @calc_components_results.each do |key, value|
      (totals.get_first_date..totals.get_last_date).each do |date|
        (0..47).each do |half_hour_index|
          totals[date][half_hour_index] += value[date][half_hour_index]
        end
      end
      sub_total = component_total(value)
      puts "Component #{key} = #{sub_total} k_wh"
    end
    @calc_components_results["Totals"] = totals
  end

  def component_total(component)
    total = 0.0
    (component.get_first_date..component.get_last_date).each do |date|
      (0..47).each do |half_hour_index|
        total += component[date][half_hour_index]
      end
    end
    total
  end

  #=======================================================================================================================================================================
  # LIGHTING SIMULATION
  #  - is a function of occupancy * external anbient lighting * peak power (which is itself a function of the lighting efficacy (efficiency of lighting * its brightness (per floor area) * the floor area )
  def simulate_lighting
    lighting_data = create_emptyAMRData("Lighting")

    peak_power =  @appliance_definitions[:lighting][:lumens_perM2] * school.floor_area / 1000 / @appliance_definitions[:lighting][:lumens_per_watt]

    (lighting_data.get_first_date..lighting_data.get_last_date).each do |date|
      (0..47).each do |half_hour_index|
        if !@holidays.is_holiday(date) && !is_weekend(date)

          solar_insol = @solar_insolence.get_solar_insolence(date, half_hour_index)
          percent_of_peak = interpolateYValue(@appliance_definitions[:lighting][:percent_on_as_function_of_solar_insolance][:solar_insolance],
                          @appliance_definitions[:lighting][:percent_on_as_function_of_solar_insolance][:percent_of_peak],
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
    points = {}
    count = 0
    xarr.each do |x|
      points[x] = yarr[count]
      count += 1
    end

    inter = Interpolate::Points.new(points)
    inter.at(x_value)
  end

  #=======================================================================================================================================================================
  # ICT SIMULATION
  #  - note this unlike the other appliance simulators produces 3 data sets - 1 for each type of server, desktop and laptop - i_pad/tablets are ignored as very low k_wh, but can be included a a laptop
  def simulate_ict
    server_data = create_emptyAMRData("Servers")
    desktop_data = create_emptyAMRData("Desktops")
    laptop_data = create_emptyAMRData("Laptops")

    @appliance_definitions[:ict].value do |ict_appliance_group|
      (server_data.get_first_date..server_data.get_last_date).each do |date| # arbitrary use the date list for te servers to iterate on, but the inner work applies via the case statement to desktops or laptops
        (0..47).each do |half_hour_index|
          on_today = !(@holidays.is_holiday(date) && ict_appliance_group.key?(:holidays) && !ict_appliance_group[:holidays])
          on_today &&= !(is_weekend(date) && ict_appliance_group.key?(:weekends) && !ict_appliance_group[:weekends])

          if on_today
            if ict_appliance_group.key?(:usage_percent_by_time_of_day)
              percent_on = ict_appliance_group[:usage_percent_by_time_of_day][half_hour_index]
              power = percent_on * ict_appliance_group[:number] * ict_appliance_group[:power_watts_each] / 1000.0
              power += (1 - percent_on) * ict_appliance_group[:number] * ict_appliance_group[:standby_watts_each] / 1000.0
            else
              power = ict_appliance_group[:number] * ict_appliance_group[:power_watts_each] / 1000.0
            end

            case ict_appliance_group[:type]
            when :server
              server_data[date][half_hour_index] += power / 2 # power kW to 1/2 hour k_wh
            when :desktop
              desktop_data[date][half_hour_index] += power / 2 # power kW to 1/2 hour k_wh
            when :laptop
              laptop_data[date][half_hour_index] += power / 2 # power kW to 1/2 hour k_wh
            end
          end
        end
      end
    end

    @calc_components_results["Servers"] = server_data
    @calc_components_results["Desktops"] = desktop_data
    @calc_components_results["Laptops"] = laptop_data
  end

  #=======================================================================================================================================================================
  # BOILER PUMP SIMULATION
  def simulate_boiler_pump
    boiler_pump_data = create_emptyAMRData("Boiler Pumps")

    pump_power = @appliance_definitions[:boiler_pumps][:pump_power]
    heating_on_during_weekends = @appliance_definitions[:boiler_pumps][:weekends]
    heating_on_during_holidays = @appliance_definitions[:boiler_pumps][:holidays]

    (boiler_pump_data.get_first_date..boiler_pump_data.get_last_date).each do |date|
      in_season = in_heating_season(@appliance_definitions[:boiler_pumps][:heating_season_start_dates], @appliance_definitions[:boiler_pumps][:heating_season_end_dates], date)
      (0..47).each do |half_hour_index|
        if in_season && !(@holidays.is_holiday(date) && !heating_on_during_holidays) && !(is_weekend(date) && !heating_on_during_weekends)

          amr_bucket_start_time = convert_half_hour_index_to_time(half_hour_index)
          amr_bucket_end_time = convert_half_hour_index_to_time(half_hour_index + 1)

          # fractionally calculate overlap to get correct k_wh on non-half hour boundary overlap
          overlap = hours_overlap_between_two_date_ranges(amr_bucket_start_time, amr_bucket_end_time, @appliance_definitions[:boiler_pumps][:start_time], @appliance_definitions[:boiler_pumps][:end_time])

          frost_protect_temp = @appliance_definitions[:boiler_pumps][:frost_protection_temp]

          # to cope with the fractional half hour case if the heating isn;t on for the full fraction of the half hour, then replace if frost protection
          # 0.5 hour period if frost protection required - in an ideal world the frost protection setting would be further interpolated by the temperatures at
          # the start and end of each bucket, to get an more accurate intercept, however this is moot given we are ignoring thermal mass

          if overlap > 0.5 && @temperatures.get_temperature(date, half_hour_index) <= frost_protect_temp
            overlap = 0.5 # i.e. half and hour
          end

          boiler_pump_data[date][half_hour_index] = pump_power * overlap # automatically in k_wh as conversion kW * time in hours
        end
      end
    end
    @calc_components_results["Boiler Pumps"] = boiler_pump_data
  end

  def is_weekend(date)
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

  # def within_boiler_on_times(start_time, end_time, half_hour_index)
  #  start_time_index = convert_time_to_half_hour_index(start_time)
  #  end_time_index = convert_time_to_half_hour_index(end_time)
  #
  #  return half_hour_index >= start_time_index && half_hour_index <= end_time_index
  # end

  def convert_time_to_half_hour_index(time)
    hour = time.hour.to_i
    half_hour_index = time.min >= 30
    hour * 2 + (half_hour_index ? 1 : 0).to_i
  end

  #=======================================================================================================================================================================
  # SECURITY LIGHTING SIMULATION
  def simulate_security_lighting
    lighting_data = create_emptyAMRData("Security Lighting")

    power = @appliance_definitions[:security_lighting][:power]

    if power >= 0.0
      control_type = @appliance_definitions[:security_lighting][:control_type]

      midnight0 = convert_half_hour_index_to_time(0)
      midnight24 = convert_half_hour_index_to_time(48)

      puts "control type #{control_type}"
      case control_type
      when "Sunrise/Sunset"
        (lighting_data.get_first_date..lighting_data.get_last_date).each do |date|
          month = date.month - 1
          sunrise_str = @appliance_definitions[:security_lighting][:sunrise_times][month]
          sunset_str = @appliance_definitions[:security_lighting][:sunset_times][month]

          sunrise = convert_time_string_to_time(sunrise_str)
          sunset = convert_time_string_to_time(sunset_str)

          (0..47).each do |half_hour_index|
            amr_bucket_start_time = convert_half_hour_index_to_time(half_hour_index)
            amr_bucket_end_time = convert_half_hour_index_to_time(half_hour_index + 1)

            # fractionally calculate overlap to get correct k_wh on non-half hour boundary overlap
            overlap = hours_overlap_between_two_date_ranges(amr_bucket_start_time, amr_bucket_end_time, midnight0, sunrise)
            overlap += hours_overlap_between_two_date_ranges(amr_bucket_start_time, amr_bucket_end_time, sunset, midnight24)

            lighting_data[date][half_hour_index] += power * overlap # automatically in k_wh as conversion kW * time in hours
          end
        end
      when "Ambient"
        (lighting_data.get_first_date..lighting_data.get_last_date).each do |date|
          (0..47).each do |half_hour_index|
            solar_insol = @solar_insolence.get_solar_insolence(date, half_hour_index)
            if solar_insol < @appliance_definitions[:security_lighting][:ambient_threshold]
              lighting_data[date][half_hour_index] += power / 2 # power kW to 1/2 hour k_wh
            end
          end
        end
      when "Fixed Times" # note the end time is early morning, so less than the start time which is early evening
        fixed_start_time_string = @appliance_definitions[:security_lighting][:fixed_start_time]
        starttime = convert_time_string_to_time(fixed_start_time_string)
        fixed_end_time_string = @appliance_definitions[:security_lighting][:fixed_end_time]
        endtime = convert_time_string_to_time(fixed_end_time_string)

        (lighting_data.get_first_date..lighting_data.get_last_date).each do |date|
          (0..47).each do |half_hour_index|
            amr_bucket_start_time = convert_half_hour_index_to_time(half_hour_index)
            amr_bucket_end_time = convert_half_hour_index_to_time(half_hour_index + 1)

            # fractionally calculate overlap to get correct k_wh on non-half hour boundary overlap
            overlap = hours_overlap_between_two_date_ranges(amr_bucket_start_time, amr_bucket_end_time, midnight0, endtime)
            overlap += hours_overlap_between_two_date_ranges(amr_bucket_start_time, amr_bucket_end_time, starttime, midnight24)

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
    Time.new(2010, 1, 1, time_str[0, 2].to_i, time_str[3, 2].to_i, 0)
  end

  def hours_overlap_between_two_date_ranges(start_time1, end_time1, start_time2, end_time2)
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
    hour = (half_hour_index / 2).floor.to_i
    mins = 30 * (half_hour_index.odd? ? 1 : 0)
    time = hour == 24 ? Time.new(2010, 1, 2, 0, mins, 0) : Time.new(2010, 1, 1, hour, mins, 0)
    time
  end
  #=======================================================================================================================================================================
  # KITCHEN SIMULATION

  def simulate_kitchen
    kitchen_data = create_emptyAMRData("Kitchen")

    power = @appliance_definitions[:kitchen][:power]

    start_time = @appliance_definitions[:kitchen][:start_time]
    end_time = @appliance_definitions[:kitchen][:end_time]

    (kitchen_data.get_first_date..kitchen_data.get_last_date).each do |date|
      (0..47).each do |half_hour_index|
        if !@holidays.is_holiday(date) && !is_weekend(date)

          amr_bucket_start_time = convert_half_hour_index_to_time(half_hour_index)
          amr_bucket_end_time = convert_half_hour_index_to_time(half_hour_index + 1)

          # fractionally calculate overlap to get correct k_wh on non-half hour boundary overlap
          overlap = hours_overlap_between_two_date_ranges(amr_bucket_start_time, amr_bucket_end_time, start_time, end_time)

          kitchen_data[date][half_hour_index] = power * overlap # automatically in k_wh as conversion kW * time in hours
        end
      end
    end
    @calc_components_results["Kitchen"] = kitchen_data
  end
  #=======================================================================================================================================================================
  # HOT WATER SIMULATION

  def simulate_hot_water
    hot_water_data = create_emptyAMRData("Hot Water")

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

    (hot_water_data.get_first_date..hot_water_data.get_last_date).each do |date|
      (0..47).each do |half_hour_index|
        if !@holidays.is_holiday(date) && !is_weekend(date)

          amr_bucket_start_time = convert_half_hour_index_to_time(half_hour_index)
          amr_bucket_end_time = convert_half_hour_index_to_time(half_hour_index + 1)

          # fractionally calculate overlap to get correct k_wh on non-half hour boundary overlap
          overlap = hours_overlap_between_two_date_ranges(amr_bucket_start_time, amr_bucket_end_time, start_time, end_time)

          hot_water_data[date][half_hour_index] = average_power * overlap # automatically in k_wh as conversion kW * time in hours

          # standby power out of schools hours

          if overlap < 0.5
            hot_water_data[date][half_hour_index] += standby_power * (0.5 - overlap)
          end
        elsif is_weekend(date) && @appliance_definitions[:electric_hot_water][:weekends]
          hot_water_data[date][half_hour_index] = standby_power * 0.5 # power kW to 1/2 hour k_wh
        elsif @holidays.is_holiday(date) && @appliance_definitions[:electric_hot_water][:holidays]
          hot_water_data[date][half_hour_index] = standby_power * 0.5 # power kW to 1/2 hour k_wh
        end
      end
    end
    @calc_components_results["Hot Water"] = hot_water_data
  end

  #=======================================================================================================================================================================
  # SUMMER AIRCON SIMULATION
  def simulate_air_con
    air_con_data = create_emptyAMRData("Air Conditioning")

    # power_per_degree_day = @appliance_definitions[:summer_air_conn][:power_per_degreeday]
    # cooling_balance_point_temperature = @appliance_definitions[:summer_air_conn][:balance_point_temperature]

    cooling_on_during_weekends = @appliance_definitions[:summer_air_conn][:weekends]
    # cooling_on_during_holidays = @appliance_definitions[:summer_air_conn][:holidays]

    base_temp = @appliance_definitions[:summer_air_conn][:balance_point_temperature]

    (air_con_data.get_first_date..air_con_data.get_last_date).each do |date|
      (0..47).each do |half_hour_index|
        if !(@holidays.is_holiday(date) && !cooling_on_during_holidays) && !(is_weekend(date) && !cooling_on_during_weekends)

          amr_bucket_start_time = convert_half_hour_index_to_time(half_hour_index)
          amr_bucket_end_time = convert_half_hour_index_to_time(half_hour_index + 1)

          overlap = hours_overlap_between_two_date_ranges(amr_bucket_start_time, amr_bucket_end_time, @appliance_definitions[:summer_air_conn][:start_time], @appliance_definitions[:summer_air_conn][:end_time])

          degree_days = @temperatures.cooling_degree_days_at_time(date, base_temp, half_hour_index)

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
    unaccounted_for_baseload_data = create_emptyAMRData("Unaccounted For Baseload")
    baseload = @appliance_definitions[:unaccounted_for_baseload][:baseload]

    (unaccounted_for_baseload_data.get_first_date..unaccounted_for_baseload_data.get_last_date).each do |date|
      (0..47).each do |half_hour_index|
        unaccounted_for_baseload_data[date][half_hour_index] = (baseload / 2) # power kW to 1/2 hour k_wh
      end
    end
    @calc_components_results["Unaccounted For Baseload"] = unaccounted_for_baseload_data
  end
  #=======================================================================================================================================================================
  # ANOTHER SIMULATION
end
