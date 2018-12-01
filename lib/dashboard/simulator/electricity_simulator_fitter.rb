 #=======================================================================================================================================================================
# MODEL FITTING - take default parameter set and fir to actual data by looking at usage patterns
# fit default parameters to actual AMR data
# this code contains the fitting functions associated with the ElectricitySimulator
# separated to reduce the size of the code base in the main file
# difficult for it to be a seperate class as it shares instance varuables and methods
class ElectricitySimulator
  def fit(appliance_definitions)
    @working_amr_data = Marshal.load(Marshal.dump(@existing_electricity_meter.amr_data))
    if @working_amr_data.start_date < @school.solar_pv.start_date
      @working_amr_data.set_min_date(@school.solar_pv.start_date)
    end

    modified_config = appliance_definitions.clone
    modified_config = fit_set_unlikely_appliances_to_zero(modified_config)
    # fit_solar_pv(modified_config)
    fit_lighting_electric_heating(modified_config)
    fit_boiler_pumps(modified_config)
    fit_ict(modified_config)
    fit_unaccounted_for_baseload(modified_config)

    # TODO(PH,21Jul2018):
    # kitchen, summer air con, electric HW, security lighting
    modified_config
  end

  private

  def fit_set_unlikely_appliances_to_zero(config)
    config[:flood_lighting][:power] = 0.0
    config[:security_lighting][:power] = 0.3
    config[:solar_pv][:kwp] = 0.0
    config[:summer_air_conn][:power_per_degreeday] = 0.0
    config
  end

  #============================================================================================
  # SOLAR PV FITTER
  #
  # solar PV fitted by correlating weekend and holiday usage on a half hourly basis
  # throughout the year versus the Sheffield Solar PV data
  # the slope of the line is the implied kWp
  # i.e. if you regress the kWh usage  versus the yield kWh/kWp, the slope is kWp

  def fit_solar_pv(config)
    kw, sol_yield, dt = fit_solar_extract_data_for_analysis(config)

    # fit_solar_pv_debug(kw, sol_yield, dt)

    kwp = fit_solar_pv_regression_analysis_kwp(kw, sol_yield, dt)

    config[:solar_pv][:kwp] = kwp

    logger.info "kwp estimate for #{@school.name} #{kwp.round(2)} kWp"
    # remove solar PV component from working data set
    solar_amr_simulated_data = simulate_solar_pv_internal(kwp, @working_amr_data.start_date, @working_amr_data.end_date)
    @working_amr_data.minus_self(solar_amr_simulated_data, 0.0)
  end

  def fit_solar_extract_data_for_analysis(config)
    kw = []
    sol_yield = []
    dt = [] # date time, only used for debug, not analytics
    (@period.start_date..@period.end_date).each do |date|
      if !@holidays.occupied?(date)
        baseload = @working_amr_data.overnight_baseload_kw(date)
        # only run from 10:00 until 5:00 - to avoid noise from panel orientation
        (20..34).each do |halfhour_index|
          pv_yield = @school.solar_pv.solar_pv_yield(date, halfhour_index)
          hh_kw = @working_amr_data.kwh(date, halfhour_index) * 2
          # only assess if yield > 100W/m2/kWp TODO(PH,24Jul2018) check yield per hr or half hr
          # and mains consumption > 200w - so not exporting (if export data is lost)
          if pv_yield > 0.1 && hh_kw > 0.1 && hh_kw < baseload * 1.2
            kw.push(hh_kw)
            sol_yield.push(pv_yield)
            dt.push(DateTimeHelper.datetime(date, halfhour_index))
          end
        end
      end
    end
    [kw, sol_yield, dt]
  end

  def fit_solar_pv_debug(kw, sol_yield, dt)
    begin
      file = File.open('Results/' + @school.name + ' ' + 'sim pv corr.csv', 'w')
      for i in (0...sol_yield.size)
        file.write("#{dt[i].strftime('%d/%m/%Y %H:%M')}, #{sol_yield[i]},#{kw[i]}\n")
      end
    rescue IOError => e
      logger.error e.message
    ensure
      file.close unless file.nil?
    end
  end

  def fit_solar_pv_regression_analysis_kwp(kw, sol_yield, dt)
    x = Daru::Vector.new(sol_yield)
    y = Daru::Vector.new(kw)
    sr = Statsample::Regression.simple(x, y)
    logger.debug "Solar PV implied kWp #{sr.b} base #{sr.a} r2 #{sr.r2}"
    kwp = sr.b < -1.0 ? -1.0 * sr.b : 0.0
    kwp
  end
  #============================================================================================
  # ELECTRICAL HEATING AND LIGHTING FITTER
  #
  # carry out multivariate regression in an attempt to disentangle impact
  # of lighting and electrical heating both of which increase in the winter
  # - lighting because its darker outside (so regress daily kWh(y) against solar irradiance (x1))
  # - electrical heating (regress kwh(y) degree days (x2))

  def fit_lighting_electric_heating(config)
    days_kwh, degree_days, irradiation, dates = fit_lighting_electric_heating_extract_data(config)

    r2, lighting_sensitivity_wrt_irradiation, heating_sensitivity_wrt_degreedays, constant = fit_lighting_electric_heating_regression_analysis(days_kwh, degree_days, irradiation)

    fit_lighting_electric_heating_debug(
      r2,
      lighting_sensitivity_wrt_irradiation,
      heating_sensitivity_wrt_degreedays,
      constant,
      dates,
      days_kwh,
      degree_days,
      irradiation
    ) if false

    fit_lighting_electric_heating_extract_heating_component(config, heating_sensitivity_wrt_degreedays)

    fit_lighting_electric_heating_extract_lighting_component(config, lighting_sensitivity_wrt_irradiation, irradiation)
  end

  def fit_lighting_electric_heating_extract_data(config)
    amr_data = @working_amr_data
    days_kwh = []
    degree_days = []
    irradiation = []
    dates = [] # debug only
    (amr_data.start_date..amr_data.end_date).each do |date| # whole meter period to reduce error term
      if @holidays.occupied?(date)
        days_kwh.push(@working_amr_data.one_day_kwh(date))
        degree_days.push(@school.temperatures.degree_days(date, HEATING_DEGREEDAY_BALANCEPOINT_TEMPERATURE))
        irradiation.push(@solar_irradiation.average_days_irradiance_between_times(date, 16, 34))
        dates.push(date)
      end
    end
    [days_kwh, degree_days, irradiation, dates]
  end

  def fit_lighting_electric_heating_regression_analysis(days_kwh, degree_days, irradiation)
    logger.debug "Regressing #{irradiation.length} samples"
    x1 = Daru::Vector.new(degree_days)
    x2 = Daru::Vector.new(irradiation)
    y = Daru::Vector.new(days_kwh)
    ds = Daru::DataFrame.new({:heating_dd => x1, :lighting_ir => x2, :kwh => y})
    lr = Statsample::Regression.multiple(ds, :kwh)
    # puts lr.summary
    [lr.r2, lr.coeffs[:lighting_ir], lr.coeffs[:heating_dd], lr.constant]
  end

  def fit_lighting_electric_heating_debug(r2, lighting_coeff, heating_coeff, constant, dates, days_kwh, degree_days, irradiation)
    begin
      file = File.open('Results/' + @school.name + ' ' + 'sim light heating corr.csv', 'w')
      file.write("#{r2}, #{heating_coeff}, #{lighting_coeff}, #{lr.constant}\n")
      for i in (0...days_kwh.size)
        calc = constant + heating_coeff * degree_days[i] + lighting_coeff * irradiation[i]
        file.write("#{dates[i].strftime('%d/%m/%Y')}, #{days_kwh[i]}, #{calc}, #{degree_days[i]}, #{irradiation[i]}\n")
      end
    rescue IOError => e
      logger.error e.message
    ensure
      file.close unless file.nil?
    end
  end

  def fit_lighting_electric_heating_extract_heating_component(config, heating_sensitivity_wrt_degreedays)
    amr_data = @working_amr_data
    # extract heating information
    fixed_power = 0.0
    hours_on = (config[:electrical_heating][:end_time] - config[:electrical_heating][:start_time]) / 60.0 / 60.0
    power_per_degreeday = heating_sensitivity_wrt_degreedays / hours_on
    power_per_degreeday = power_per_degreeday < 0.0 ? 0.0 : power_per_degreeday
    config[:electrical_heating][:power_per_degreeday] = power_per_degreeday
    config[:electrical_heating][:fixed_power] = fixed_power
    logger.info "Power per degree day: #{power_per_degreeday}"
    if power_per_degreeday > 0.0
      heating_amr_simulated_data = simulate_electrical_heating_internal(
        power_per_degreeday,
        HEATING_DEGREEDAY_BALANCEPOINT_TEMPERATURE,
        fixed_power,
        amr_data.start_date,
        amr_data.end_date,
        config[:electrical_heating]
      )
      @working_amr_data.minus_self(heating_amr_simulated_data, 0.0)
    end
  end

  def fit_lighting_electric_heating_extract_lighting_component(config, lighting_sensitivity_wrt_irradiation, irradiation)
    # extract lighting information
    # - this is a little complicated as the regression coefficient is negative
    # - i.e. the brighter it is outside the less lighting is on
    # -      and conversely if its dark outside (solar ir = 0) then all the lighting is on
    # -      and because we are only doing this at a daily level we only have a dailt average representation
    # -      previous modelling suggests 800W/m2 and above represents full ambient brightness i.e. a sunny day
    # -      although in the peak of summer this can rise to 1400W/m2 (Bath Lower Weston weather station)
    # - so as an example, St Marks has a coefficient of -0.46kWh/solar ir (w/m2)
    # - so on an average day of perhaps 400W/m2, about 50% of the lighting will be on for a 10 hour period
    # - so (800W/m2 - 400W/m2) * -0.46 = 184kWh lighting usage per day
    # - so over 10 hours about 18.4 kW average, but because its a day of average brightness only 50%
    # - of lights are on, so this implied a peak 36.8 kW lighting usage for a 5,200 m2 floor area
    # - which implied 36.8 kW/5,200 = 7W/m2
    # - default assumptions: an efficacy of 50 lumens/watt and a brightness of 400 lumens/m2, implies 400/50 = 8W/m2
    # - if you assume a default brightness of 400 lumens per watt:
    #     -the implied efficacy would be 400/7 = 57 lumens/watt
    # therefore:
    weighted_hours = sumproduct_lighting_occupancy_hours(config[:lighting])
    average_irradiance = irradiation.inject { |sum, el| sum + el }.to_f / irradiation.size
    logger.debug "Average irradiance = #{average_irradiance}"
    lighting_kwp = (800.0 - average_irradiance) * -1.0 * lighting_sensitivity_wrt_irradiation / weighted_hours / 0.5
    logger.info "Implied peak lighting power: #{lighting_kwp}"
    watts_per_m2 = (1000.0 * lighting_kwp) / @school.floor_area
    logger.info "Lighting watts per m2: #{watts_per_m2}"
    efficacy_lumens_per_watt = config[:lighting][:lumens_per_m2] / watts_per_m2
    logger.info "Lighting efficacy: #{efficacy_lumens_per_watt}"
    if efficacy_lumens_per_watt > 15 && efficacy_lumens_per_watt < 110 # a slight fudge
      config[:lighting][:lumens_per_watt] = efficacy_lumens_per_watt
    end
  end

  #============================================================================================
  # BOILER PUMP FITTER
  #
  # boiler pump consumption can often be picked up in the early morning in schools
  # however, it is often small but subtle, so perhaps 400W for a small primary through
  # to 4 kW for a secondary. Visual observation often shows a jump from baseload in
  # electrical consumption around the time gas consumption jumps when thee heating comes on
  #
  def fit_boiler_pumps(config)
    if @school.aggregated_heat_meters.nil?
      config[:boiler_pumps][:pump_power] = 0.0
    else
      pump_power, gas_power = calculate_boiler_pump_power
      config[:boiler_pumps][:pump_power] = pump_power
      config[:boiler_pumps][:boiler_gas_power_on_criteria] = gas_power * 0.2 # use 20% of peak
    end
  end

  # potentially reusable for alert functionality i.e. is the boiler coming on too early?
  def calculate_boiler_pump_power
    boiler_gas_power = average_boiler_gas_peak_on_kw

    boiler_gas_on_criteria = average_boiler_gas_peak_on_kw * 0.45 # arbitrary 55%

    boiler_pump_power = average_boiler_pump_power(boiler_gas_on_criteria)

    logger.info "Estimated boiler pump power: #{boiler_pump_power} kW (average peak gas power: #{boiler_gas_power} kW)"

    if boiler_pump_power * 1000 > @school.floor_area # i.e. estimate > 1W per m2 i.e. poor estimate
      boiler_pump_power = @school.floor_area * 0.5 / 1000.0 # 500W per 1000m2 is a good average
      logger.info "Estimate too high, using a rule: new estimate #{boiler_pump_power}"
    end
    [boiler_pump_power, boiler_gas_power]
  end

  def average_boiler_pump_power(boiler_gas_on_criteria)
    total= 0.0
    count = 0
    (@period.start_date..@period.end_date).each do |date|
      on_time_hh_index = boiler_start_time(date, boiler_gas_on_criteria)

      boiler_pump_power = boiler_pump_power_estimate(date, on_time_hh_index)

      unless boiler_pump_power.nil?
        total += boiler_pump_power
        count += 1
      end
    end
    count > 0 ? (total / count) : 0.0
  end

  def boiler_pump_power_estimate(date, on_time_hh_index)
    electric_data = @existing_electricity_meter.amr_data

    # only look at heating if turned on after 1:00am (so we can go back an hour)
    # and before 6:00am (school opening interferring with statistics)
    if !on_time_hh_index.nil? &&
        on_time_hh_index > 2 &&
        on_time_hh_index < 12 &&
        electric_data.key?(date)
      # avoid measuring power in the half hour the boiler is switching on
      # as it may be a partial reading i.e. don't use electric_data.kwh(date,0)
      electricity_power_before = 2.0 * (electric_data.kwh(date,on_time_hh_index - 1) + electric_data.kwh(date,on_time_hh_index - 2) ) / 2.0
      electricity_power_after = 2.0 * (electric_data.kwh(date,on_time_hh_index + 1) + electric_data.kwh(date,on_time_hh_index + 2) ) / 2.0
      diff = electricity_power_after - electricity_power_before
      return diff if diff > 0.2 # use 200W as minimum criteria
    end
    nil
  end

  def boiler_start_time(date, boiler_gas_on_criteria)
    on_time_hh_index = nil
    if heating_on?(date) && @school.aggregated_heat_meters.amr_data.key?(date)
      (0..47).each do |halfhour_index|
        if @school.aggregated_heat_meters.amr_data.kwh(date, halfhour_index) * 2.0 > boiler_gas_on_criteria
          on_time_hh_index = halfhour_index
          break # for speed
        end
      end
    end
    on_time_hh_index
  end

  def boiler_end_time(date, boiler_gas_off_criteria)
    on_time_hh_index = nil
    if heating_on?(date) && @school.aggregated_heat_meters.amr_data.key?(date)
      47.downto(0).each do |halfhour_index|
        if @school.aggregated_heat_meters.amr_data.kwh(date, halfhour_index) * 2.0 > boiler_gas_off_criteria
          on_time_hh_index = halfhour_index
          break # for speed
        end
      end
    end
    on_time_hh_index
  end

  # determine a kW value for when the boiler is running for heating
  # by scanning the heating days, calculating an average peak usage
  def average_boiler_gas_peak_on_kw
    total = 0.0
    count = 0
    (@period.start_date..@period.end_date).each do |date|
      if heating_on?(date) && @school.aggregated_heat_meters.amr_data.key?(date)
        kw_peak = @school.aggregated_heat_meters.amr_data.statistical_peak_kw(date)
        total += kw_peak
        count += 1
      end
    end
    total / count
  end

  #============================================================================================
  # ICT FITTER
  def fit_ict(config)
    fit_servers(config)
    fit_desktops_laptops(config)
  end

  def fit_servers(config)
    num_servers, power = BenchmarkMetrics.typical_servers_for_pupils(@school.school_type, @school.number_of_pupils)
    config[:ict][:servers][:number] = num_servers
    config[:ict][:servers][:power_watts_each] = power
  end

  def fit_desktops_laptops(config)
    teachers = (@school.number_of_pupils / 20 ).round
    school_type = @school.school_type.to_sym

    case school_type
    when :primary, :infant, :junior, :special
      num_intakes = (@school.number_of_pupils / (6 * 30)).ceil
      # 1 head, 2 admin staff per intake classes (+1) + 1 per teacher
      admin_staff = 2 * num_intakes + 1
      config[:ict][:desktops][:number] = 1 + admin_staff + teachers
      # 30 per intake, but only on 50% of time
      config[:ict][:laptops][:number] = (num_intakes * 30 * 0.5).round
    when :secondary
      num_classrooms = (@school.number_of_pupils / 20).ceil
      num_admin_staff = 2 + (@school.number_of_pupils / 125).ceil
      num_computer_labs = (@school.number_of_pupils / 300).ceil
      # often 'computer labs' in secondaries use lighterweight more energy efficient desktops
      num_lab_desktops = num_computer_labs * 25
      config[:ict][:desktops][:number] = num_classrooms + num_computer_labs + num_admin_staff
      config[:ict][:desktops][:power_watts_each] = (150 * num_admin_staff + 100 * num_classrooms + 70 * num_lab_desktops) / (num_admin_staff + num_classrooms + num_lab_desktops)
      config[:ict][:laptops][:number] = (config[:ict][:desktops][:number] / 10).ceil
    else
      raise EnergySparksUnexpectedStateException.new("Unknown school type #{@school.school_type}") if !@school.school_type.nil?
      raise EnergySparksUnexpectedStateException.new('Nil school type') if @school.school_type.nil?
    end
  end

  #============================================================================================
  # UNACCOUNTED FOR BASELOAD FITTER
  # set the unaccounted for baseload to the difference between that predicted for servers and
  # other always on appliances and the actula baseload
  def fit_unaccounted_for_baseload(config)
    amr_data = @existing_electricity_meter.amr_data
    baseload = amr_data.average_overnight_baseload_kw_date_range(@period.start_date, @period.end_date)
    if config[:kitchen].key?(:average_refridgeration_power)
      baseload += config[:kitchen][:average_refridgeration_power] / 2.0 # kW to kWh per 0.5 hour
    end
    unaccounted_for_baseload = baseload - ict_baseload(config)
    unaccounted_for_baseload = [unaccounted_for_baseload, 0.0].max
    config[:unaccounted_for_baseload][:baseload] = unaccounted_for_baseload
  end
end
