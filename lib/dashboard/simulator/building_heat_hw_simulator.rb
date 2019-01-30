class BuildingHeatHWSimulator
  include Logging

  attr_reader :school, :holidays, :temperatures, :solar_irradiation, :solar_pv
  attr_reader :calc_components_results, :simulation_frequency
  attr_reader :simulation_start_date, :simulation_end_date

  def initialize(school, start_date, end_date, simulation_frequency = 3)
    @school = school
    set_schedule_data(school)
    @simulation_start_date = start_date
    @simulation_end_date = end_date
    @simulation_frequency = simulation_frequency # num per 1/2 hour
    @calc_components_results = {}
    @super_debug = true
  end

  def simulate
    bm = Benchmark.measure {
      run_simulation
    }
    puts "Simulation took #{bm.to_s}"
  end

  private

  def set_schedule_data(school)
    @holidays = school.holidays
    @temperatures = school.temperatures
    @solar_irradiation = school.solar_irradiation
    @solar_pv = school.solar_pv
  end

  def create_empty_data(type)
    data = {}
    (simulation_start_date..simulation_end_date).each do |date|
      data[date] = Array.new(48 * simulation_frequency, 0.0)
    end
    logger.debug "Creating empty #{type} simulator data, #{data.length} elements"
    data
  end

  def occupied_date_time?(date, day_index)
    # Note - is_school_usually_open? is currently defined at meter collection level
    occupied?(date) && school.is_school_usually_open?(date, time_of_day(day_index))
  end

  def occupied?(date)
    !weekend?(date) && !holiday?(date)
  end

  def weekend?(date)
    DateTimeHelper.weekend?(date)
  end

  def holiday?(date)
    @holidays.holiday?(date)
  end

  def simulation_period_in_hours
    1 / (2.0 * simulation_frequency)
  end

  def date_and_simulation_index_to_time(date, simulation_day_index)
    hour, minute = index_to_hour_minute(simulation_day_index)
    Time.new(date.year, date.month, date.day, hour, minute, 0)
  end

  def time_of_day(day_index)
    hour, minute = index_to_hour_minute(day_index)
    TimeOfDay.new(hour, minute)
  end

  def index_to_hour_minute(day_index)
    hour = (day_index/(2 * simulation_frequency)).floor.to_i
    remaining_index_within_hour = day_index - (hour * 2 * simulation_frequency)
    minute = remaining_index_within_hour * (60 / (2 * simulation_frequency))
    [hour, minute]
  end

  def simulation_index_to_halfhour_index(simulation_index)
    (simulation_index/simulation_frequency).floor.to_i
  end

  def electrical_gain_kw(date, day_index)
    occupied_date_time?(date, day_index) ? occupied_electrical_gain_kw : unoccupied_electrical_gain_kw
  end

  def occupied_electrical_gain_kw
    (20.0 / 1000) * school.floor_area
  end

  def unoccupied_electrical_gain_kw
    (2.5 / 1000) * school.floor_area
  end

  def pupil_gain_kw(date, day_index)
    if occupied_date_time?(date, day_index)
      pupil_gain_occupied_kw
    else
      0.0
    end
  end

  def pupil_gain_occupied_kw
    (60.0 / 1000.0) * school.number_of_pupils
  end

  def gross_wall_area
    wall_length * wall_height
  end

  def window_area
    window_area_percent = 0.25
    window_area_percent * gross_wall_area
  end

  def net_external_wall_area
    gross_wall_area - window_area
  end

  def volume
    school.floor_area * wall_height
  end

  def wall_length
    4 * Math.sqrt(school.floor_area)
  end
  def wall_height
    3.0
  end

  def fabric_loss_kw_per_k
    u_value_wall = 1.5
    u_value_window = 2.7
    u_value_ceiling = 0.5
    perimeter_to_floor_area_ratio = wall_length / school.floor_area
    u_value_floor = 0.05 + 1.65 * perimeter_to_floor_area_ratio - 0.6 * (perimeter_to_floor_area_ratio**2.0)

    fabric_loss_w_per_k = u_value_wall * net_external_wall_area
    fabric_loss_w_per_k += u_value_window * window_area
    fabric_loss_w_per_k += u_value_ceiling * school.floor_area
    fabric_loss_w_per_k += u_value_floor * school.floor_area

    fabric_loss_w_per_k /1000.0
  end

  # per m3
  def heat_capacity_kwh_per_m3_per_k(material)
    case material
    when :air
      0.00034 # kwh/m3/K (1000J/kg * 1.2kg/m3/K / 3,600,000 kWh/J)
    when :water
      4.2 * 1000 * 1000 / 3_600_000 # kwh/m3/K
    when :concrete
      # 1,0 J/g/K heat capacity * 1000 g/kg * 2000 kg/m3 / 3600000 J/kWh
      1.0 * 1000 * 2000 / 3_600_000 # kwh/m3/K
    end
  end

  def set_point_temperature
    21.0
  end

  def air_heat_loss_kw(permeability_m3_per_hr, delta_t)
    permeability_m3_per_hr * delta_t * heat_capacity_kwh_per_m3_per_k(:air)
  end

  def air_permeability_m3_per_hr(date, day_index)
    loss = uncontrolled_air_permeability_per_hr(date, day_index)
    loss += controlled_air_permeability_per_hr(date, day_index) if occupied_date_time?(date, day_index)
  end

  def controlled_air_permeability_m3_per_hr(date, day_index)
    if date.nil? || occupied_date_time?(date, day_index)
      recommend_ventilation_per_pupil = 5.0 # l/s
      school.number_of_pupils * (recommend_ventilation_per_pupil / 1000) * 3600.0
    else
      0.0
    end
  end

  def uncontrolled_air_permeability_m3_per_hr(_date, _day_index)
    air_permeability_at_50_pa = 6.5 # ACH
    shelterfactor = 0.07
    air_permeability_at_50_pa * shelterfactor * volume
  end

  def thermal_mass_building_kwh_per_k
    # http://www.greenspec.co.uk/building-design/thermal-mass/
    useful_thickness = 0.1
    volume = total_internal_external_wall_area * useful_thickness
    volume += school.floor_area * useful_thickness
    volume * heat_capacity_kwh_per_m3_per_k(:concrete)
  end

  def total_wall_area_factor_of_net_wall_area
    2.0 # assume internal walls same area as external
  end

  def total_internal_external_wall_area
    total_wall_area_factor_of_net_wall_area * net_external_wall_area
  end

  def construction_heat_admittance_w_per_m2_per_k(material)
    case material # http://www.greenspec.co.uk/building-design/thermal-mass/
    when :timber_frame_plaster_board
      1.0
    when :aircrete_cavity_plasterboard
      1.85
    when :aircrete_cavity_wet_plaster
      2.65
    when :dense_masonary_cavity_plasterboard
      2.65
    when :dense_masonary_cavity_wet_plaster
      5.04
    end
  end

  def construction_heat_admittance_kw_per_m2_per_k(material)
    construction_heat_admittance_w_per_m2_per_k(material) / 1000.0
  end

  def admittance_kw(delta_t)
    ad = total_internal_external_wall_area * construction_heat_admittance_kw_per_m2_per_k(:dense_masonary_cavity_wet_plaster)
    ad += school.floor_area * construction_heat_admittance_kw_per_m2_per_k(:dense_masonary_cavity_wet_plaster) * 0.5
    ad * delta_t
  end

  def boiler_power_kw
    0.08 * school.floor_area
  end

  def radiator_power_kw
    0.04 * school.floor_area
  end

  def simulations_per_day
    simulation_frequency * 48
  end

  def balance_point_occupied
    gains_kw = occupied_electrical_gain_kw + pupil_gain_occupied_kw
    losses_kw_per_k =   air_heat_loss_kw(uncontrolled_air_permeability_m3_per_hr(nil, nil), 1.0) +
                        air_heat_loss_kw(controlled_air_permeability_m3_per_hr(nil, nil), 1.0) +
                        fabric_loss_kw_per_k
    set_point_temperature - (gains_kw / losses_kw_per_k)
  end

  def balance_point_unoccupied
    gains_kw = unoccupied_electrical_gain_kw
    losses_kw_per_k =   air_heat_loss_kw(uncontrolled_air_permeability_m3_per_hr(nil, nil), 1.0) +
                        fabric_loss_kw_per_k
    set_point_temperature - (gains_kw / losses_kw_per_k)
  end

  LOG_DEFINITION = {
    internal_temperature:               'Internal Temperature',
    external_temperature:               'External Temperature',
    wall_temperature:                   'Wall Temperature',
    delta_t:                            'Delta T',
    occupied:                           'Occupied',
    occupation_gain_kw:                 'Occupation Gain',
    electical_gain_kw:                  'Electrical Gain',
    human_gain_kw:                      'Human Gain',
    fabric_loss_kw:                     'Fabric Loss',
    controlled_ventilation_loss_kw:     'Controlled Ventilation Loss',
    uncontrolled_ventilation_loss_kw:   'Uncontrolled Ventilation Loss',
    heating_gain_kw:                    'Heating Gain',
    admittance_kw:                      'Admittance',
    wall_heating_rate_k_per_hour:       'Rate of Wall Heating Per Hour',
    net_gain_kw:                        'Net loss in kW'
  }.freeze

  def create_log
    @log = {}
    LOG_DEFINITION.each do |type, description|
      @log[type] = create_empty_data(description)
    end
  end

  def log(type, date, simulation_day_index, value)
    @log[type][date][simulation_day_index] = value
  end

  def run_simulation
    create_log

    internal_temp = @temperatures.temperature(simulation_start_date, 0) # assume internal temp = external on first day
    wall_temp = internal_temp

    meta_data_log = {
      'Fabric Loss Per kW/K'          => fabric_loss_kw_per_k,
      'Boiler Power kW'               => boiler_power_kw,
      'Radiator Power kW'             => radiator_power_kw,
      'Volume m3'                     => volume,
      'Floor/Roof Area m2'            => school.floor_area,
      'Net Wall Area m2'              => net_external_wall_area,
      'Window Area m2'                => window_area,
      'Uncontrolled Ventilation kW/K' => air_heat_loss_kw(uncontrolled_air_permeability_m3_per_hr(nil, nil), 1.0),
      'Controlled Ventilation kW/K'   => air_heat_loss_kw(controlled_air_permeability_m3_per_hr(nil, nil), 1.0),
      'Thermal Mass kWh/K'            => thermal_mass_building_kwh_per_k,
      'Air Mass kWh/K'                => air_heat_loss_kw(volume, 1.0),
      'Admittance kW/K'               => admittance_kw(1.0),
      'Occupied balance point'        => balance_point_occupied,
      'Unoccupied balance point'      => balance_point_unoccupied,
      'Occupied gain'                 => occupied_electrical_gain_kw + pupil_gain_occupied_kw,
      'Unoccupied gain'               => unoccupied_electrical_gain_kw
    }

    (simulation_start_date..simulation_end_date).each do |date|
      (0...simulations_per_day).each do |simulation_day_index|
        sdi = simulation_day_index # for brevity

        occupied = occupied_date_time?(date, sdi)

        external_temp = @temperatures.temperature(date, simulation_index_to_halfhour_index(sdi))

        delta_t = internal_temp - external_temp

        gains_kw = pupil_gain_kw(date, sdi) + electrical_gain_kw(date, sdi)

        fabric_loss_kw = fabric_loss_kw_per_k * delta_t
        controlled_ventilation_loss_kw   = air_heat_loss_kw(controlled_air_permeability_m3_per_hr(date, sdi), delta_t)
        uncontrolled_ventilation_loss_kw = air_heat_loss_kw(uncontrolled_air_permeability_m3_per_hr(date, sdi), delta_t)
        losses_kw = fabric_loss_kw + controlled_ventilation_loss_kw + uncontrolled_ventilation_loss_kw
        net_gain_kw = gains_kw - losses_kw

        if occupied && external_temp < 15.0
          net_gain_kw += radiator_power_kw
        end

        # admittance can be positive or negative
        # if positive i.e. accepting heat:
        #   - it can't be more than the net internal gain
        #   - for the moment we will limit the set point to 20C
        #   - ignoring the overheating issue in the summer (more ventilation required)
        # once the building is unoccupied:
        #   - the set point temperature will be maintained or exceeded until the balance point temperature is achieved
        #   = electrical gain - fabric loss(K) - uncontrolled ventilation loss (K) = 0
        #     e.g. 3 kW - 1.6dK - 0.6dK = 0; dK = 3/(1.6 + 0.6) = 1.4C i.e. at 20C - 1.4C = Tbp = 18.6C external
        #          FYI: the occupied balance point is e.g.
        #          36 kW - 1.6dK - 0.6dK - 1.2dK; dK = 10.6K => Tbp = 9.6C external
        #   -
        # if negative i.e. providing heat:
        #   - it can't be more than the net internal loss (-tve gain)
        admittance = admittance_kw(internal_temp - wall_temp)

        if occupied # assume this implies heating on as well
          internal_temp = set_point_temperature
          rate_of_wall_heating_per_hour_kw = [admittance_kw(internal_temp - wall_temp), net_gain_kw].min
        else # assume this implies heating off
          internal_temp = wall_temp
          rate_of_wall_heating_per_hour_kw = [admittance_kw(internal_temp - wall_temp), net_gain_kw].min
        end

#        rate_of_wall_heating_per_hour_kw =  / thermal_mass_building_kwh_per_k
rate_of_wall_heating_per_hour = 1.0
        rate_of_wall_heating_per_simulation = rate_of_wall_heating_per_hour / simulation_period_in_hours
        wall_temp += rate_of_wall_heating_per_simulation

        if occupied && external_temp < 15.0
          heating_kwh = simulation_period_in_hours * radiator_power_kw

          if internal_temp < set_point_temperature
            change_in_thermal_mass_t = heating_kwh / thermal_mass_building_kwh_per_k
            internal_temp += change_in_thermal_mass_t
            # exit if internal_temp == Float::NAN
          else
            internal_temp = set_point_temperature
            wall_temp = internal_temp
          end
        end
        loss_kwh =  1 # net_losses_kw * simulation_period_in_hours
        change_in_thermal_mass_t = loss_kwh / thermal_mass_building_kwh_per_k
        internal_temp -= change_in_thermal_mass_t

        if @super_debug
          log(:occupied,                          date, sdi, occupied)
          log(:external_temperature,              date, sdi, external_temp)
          log(:internal_temperature,              date, sdi, internal_temp)
          log(:wall_temperature,                  date, sdi, wall_temp)
          log(:delta_t,                           date, sdi, delta_t)
          log(:electical_gain_kw,                 date, sdi, electrical_gain_kw(date, sdi))
          log(:human_gain_kw,                     date, sdi, pupil_gain_kw(date, sdi))
          log(:controlled_ventilation_loss_kw,    date, sdi, controlled_ventilation_loss_kw)
          log(:uncontrolled_ventilation_loss_kw,  date, sdi, uncontrolled_ventilation_loss_kw)
          log(:fabric_loss_kw,                    date, sdi, fabric_loss_kw)
          log(:net_gain_kw,                       date, sdi, net_gain_kw)
          log(:wall_heating_rate_k_per_hour,      date, sdi, rate_of_wall_heating_per_hour)
        end
        # total_kwh[date][simulation_day_index] = power * 0.5
      end
    end
    save_raw_data_to_csv_for_debug('building simulator debug.csv', meta_data_log) if @super_debug
  end

  def save_raw_data_to_csv_for_debug(filename, meta_data_log)
    filepath = File.join(File.dirname(__FILE__), '../../../log/' + filename)

    File.open(filepath, 'w') do |file|
      meta_data_log.each do |key, value|
        file.puts("#{key},#{value}")
      end
      types = LOG_DEFINITION.keys
      file.puts 'DateTime,' + types.join(',')
      (simulation_start_date..simulation_end_date).each do |date|
        (0...simulations_per_day).each do |simulation_day_index|
          datetime = date_and_simulation_index_to_time(date, simulation_day_index)
          line_data = []
          line_data.push(datetime.strftime('%Y-%m-%d %H:%M:%D'))
          line_data += types.map { |type| @log[type][date][simulation_day_index] }
          file.puts line_data.join(',')
        end
      end
    end
  end

  def self.default_configuration_deprecated(school)
    building = {
      building: MeterCollection.new("Test School", "Bath", 1100.0, 200.0),
      thermal_mass: "Medium Weight",
      surface_area_to_volume_ratio: "Compact",
      boiler: { max_power: 200.0, # needs converting to function of floor area
                        boiler_efficiency: 0.85,
                        control: {
                          optimum_start: true,
                          weather_compensation: false,
                          optimum_stop: false,
                          day_time_setback: true,  day_time_setback_delta_temp: 15.0,
                          frost_protection: true,  frost_room_temp: 10.0, external_frost_temp: 4.0,
                          hysteresis_temp: 1.5,
                          room_set_point: 20.0,
                          occupancy_start_time: "06:00",
                          occupancy_end_time: "16:00"
                        } },
      uncontrolled_air_permeability: 7.0, # ACH at 50Pa
      air_permeability_shelter_factor: 0.07,
      per_pupil_ventilation: 5.0, # litres / second
      radiator_output_perM2: 0.04, # kW @ 70C
      window_solar_gain_factor: 0.25, # percent of vertical solar insolence causing internal gain
      window_opening_area: 0.0088 # m2 per pupil
    }
    building
  end
end
