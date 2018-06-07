require_relative 'amrdata'
require 'rubygems'
require 'interpolate'
require 'benchmark'

class BuildingHeatHWSimulator
  attr_reader :period, :holidays, :temperatures, :total, :appliance_definitions, :calc_components_results, :solar_insolence, :school
  def initialize(period, holidays, temperatures, solarinsolence, school)
    @period = period
    @holidays = holidays
    @temperatures = temperatures
    @solar_insolence = solarinsolence
    @school = school
    @calc_components_results = {}

    @building = {
      building: Building.new("Test School", "Bath", 1100.0, 200.0),
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
  end

  def create_empty_amr_data(type)
    data = AMRData.new(type)
    (period.start_date..period.end_date).each do |date|
      data.add(date, Array.new(48, 0.0))
    end
    puts "Creating empty #{type} simulator data, #{data.length} elements"
    data
  end

  def simulate_building
    # some basic calculations
    occupied_electrical_gain = (20.0 / 1000) * school.floor_area
    # un_occupied_electrical_gain = (2.5 / 1000) * school.floor_area

    pupil_gain = (60.0 / 1000.0) * school.pupils

    wall_length = 4 * Math.sqrt(school.floor_area)
    wall_height = 3
    gross_wall_area = wall_length * wall_height
    window_area_percent = 0.25
    window_area = (1.00 - window_area_percent) * gross_wall_area
    net_wall_area = gross_wall_area - window_area
    volume = school.floor_area * wall_height

    u_value_wall = 1.5
    u_value_window = 2.7
    u_value_ceiling = 0.5
    perimeter_to_floor_area_ratio = wall_length / school.floor_area
    u_value_floor = 0.05 + 1.65 * perimeter_to_floor_area_ratio - 0.6 * (perimeter_to_floor_area_ratio**2.0)

    air_permeability_at_50_pa = 6.5 # ACH
    shelterfactor = 0.07

    # heat_capacity_concrete = 0.66 # _kwh/m3/K
    heat_capacity_air = 0.00034 # _kwh/m3/K/m3/K
    # heat_capacity_water = 1.67 # _kwh/m3/K/m3/K

    recommend_ventilation_per_pupil = 5.0 # l/s

    # thermal_mass_per_m2_wall = 0.1 * heat_capacity_concrete + 0.5 * 0.1 * heat_capacity_concrete # assume all of inner leaf and half of outer
    puts "dims #{gross_wall_area} #{net_wall_area} #{window_area} #{u_value_floor}"
    fabric_loss_kw_per_k = u_value_wall * net_wall_area
    fabric_loss_kw_per_k += u_value_window * window_area
    fabric_loss_kw_per_k += u_value_ceiling * school.floor_area
    fabric_loss_kw_per_k += u_value_floor * school.floor_area
    fabric_loss_kw_per_k /= 1000.0

    puts "fabric loss #{fabric_loss_kw_per_k}"

    uncontrolled_ventilationk_w_per_k = air_permeability_at_50_pa * shelterfactor * volume * heat_capacity_air
    controlled_ventilationk_w_per_k = (recommend_ventilation_per_pupil / 1000) * 3600.0 * heat_capacity_air

    thermal_mass_kwh__per_k = wall_length * 2 * wall_height * thermal_mass_perM2Wall # assume internal wall volume sinimar to external i.e. x2
    puts "thermal mass #{thermal_mass_kwh__per_k}"
    total_kwh = create_emptyAMRData('Some Component')
    puts @building.inspect# rub
    power = @building[:boiler][:max_power] # need to be careful whether this is used net or gross of efficiency
    max_radiator_power_kw = @building[:radiator_output_per_m2] * school.floor_area

    internal_temp = @temperatures.get_temperature(total_kwh.get_first_date, 0) # assume internal temp = external on first day
    # boiler_start_time = convert_time_string_to_time(@building[:boiler][:control][:occupancy_start_time])
    # boiler_end_time = convert_time_string_to_time(@building[:boiler][:control][:occupancy_end_time])

    (total_kwh.get_first_date..total_kwh.get_last_date).each do |date|
      (0..47).each do |half_hour_index|
        period_in_hours = 0.5

        if !@holidays.is_holiday(date) && !is_weekend(date)

          external_temp = @temperatures.get_temperature(date, half_hour_index)
          delta_t = internal_temp - external_temp

          gains_kw = occupied_electrical_gain + pupil_gain

          losses_kw_per_k = fabric_loss_kw_per_k + uncontrolled_ventilationk_w_per_k + controlled_ventilationk_w_per_k

          losses_kw = losses_kw_per_k * delta_t

          net_losses_kw = losses_kw - gains_kw

          if half_hour_index >= 9 * 2 && half_hour_index <= 16 * 2
            # puts "date #{date} hhindex #{half_hour_index} internal temp #{internal_temp} external temp #{external_temp} net losses #{losses_kw}"
            heating_kwh = period_in_hours * max_radiator_power_kw

            if internal_temp < @building[:boiler][:control][:room_set_point]
              change_in_thermal_mass_t = heating_kwh / thermal_mass_kwh__per_k
              internal_temp += change_in_thermal_mass_t
            end
          end

          loss_kwh = net_losses_kw * period_in_hours
          change_in_thermal_mass_t = loss_kwh / thermal_mass_kwh__per_k
          internal_temp -= change_in_thermal_mass_t

          puts "date #{date} hhindex #{half_hour_index} internal temp #{internal_temp.round(1)} external temp #{external_temp.round(1)} internal gain #{gains_kw.round(1)} losses #{losses_kw.round(1)} net losses #{net_losses_kw.round(1)} rad gain #{max_radiator_power_kw.round(1)}"
          total_kwh[date][half_hour_index] = power * 0.5

        end
      end
    end
  end

  def convert_time_string_to_time(time_str)
    Time.new(2010, 1, 1, time_str[0, 2].to_i, time_str[3, 2].to_i, 0)
  end

  def is_weekend(date)
    date.saturday? || date.sunday?
  end
end
