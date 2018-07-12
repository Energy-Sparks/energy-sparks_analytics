class ElectricitySimulatorConfiguration

   APPLIANCE_DEFINITIONS = {
    lighting:
    {
      title: 'Lighting',
      editable: [:lumens_per_watt, :lumens_per_m2],
      lumens_per_watt: 50.0,
      lumens_per_m2: 450.0,
      percent_on_as_function_of_solar_irradiance: {
        solar_irradiance: [0, 100, 200, 300, 400, 500, 600,  700, 800, 900, 1000, 1100, 1200],
        percent_of_peak: [0.9, 0.8, 0.7, 0.6, 0.5, 0.2, 0.2, 0.15, 0.1, 0.1,  0.1,  0.1,  0.1],
      },
      occupancy_by_half_hour:
        [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0.05, 0.1, 0.3, 0.5, 0.8, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0.8, 0.6, 0.4, 0.2, 0.15, 0.15, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
    },
    ict: {
      title: 'ICT',
      'Servers1' => {
        editable:                 [:number, :power_watts_each],
        type:                     :server,
        number:                   2.0,
        power_watts_each:         300.0,
        air_con_overhead_pecent:  0.2
      },
      'Servers2' => { #### Example use only, not required immediately
        editable:                 [:number, :power_watts_each],
        type:                     :server,
        number:                   1.0,
        power_watts_each:         500.0,
        air_con_overhead_pecent:  0.3
      },
      'Desktops' => {
        editable:                     [:number, :power_watts_each, :standby_watts_each],
        type:                         :desktop,
        number:                       20,
        power_watts_each:             100,
        standby_watts_each:           10,
        usage_percent_by_time_of_day: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0.05, 0.1, 0.3, 0.5, 0.8, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0.8, 0.6, 0.4, 0.2, 0.15, 0.15, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
        weekends:                     true, # left on standy at weekends
        holidays:                     false # left on standby during holidays
      },
      'Laptops' => {
        editable:                     [:number, :power_watts_each, :standby_watts_each],
        type:                         :laptop,
        number:                       20,
        power_watts_each:             30,
        standby_watts_each:           2
      }
    },
    boiler_pumps: {
      title: 'Boiler pumps',
      editable:                     [:pump_power],
      heating_season_start_dates:   [Date.new(2016, 10, 1),  Date.new(2017, 11, 5)],
      heating_season_end_dates:     [Date.new(2017,  5, 14),  Date.new(2018, 5, 1)],
      start_time:                   Time.new(2010,  1,  1,  5, 30, 0),    # Ruby doesn't have a time class, just DateTime, so the 2010/1/1 should be ignored
      end_time:                     Time.new(2010,  1,  1,  17, 0, 0),    # ditto
      pump_power:                   0.5, # 1 kw
      weekends:                     false,
      holidays:                     true,
      frost_protection_temp:        4
    },
    security_lighting: {
      title: 'Security lighting',
      editable:                     [:power, :control_type],
      control_type:       ['Sunrise/Sunset', 'Ambient', 'Fixed Times'],  # Choose one of these with radio button
      sunrise_times:      ['08:05', '07:19', '06:19', '06:10', '05:14', '04:50', '05:09', '05:54', '06:43', '07:00', '07:26', '08:06'], # by month - in string format as more compact than new Time - which it needs converting to
      sunset_times:       ['16:33', '17:27', '18:16', '20:08', '20:56', '21:30', '21:21', '20:32', '19:24', '18:17', '16:21', '16:03'], # ideally front end calculates based on GEO location
      fixed_start_time:   '19:15',
      fixed_end_time:     '07:20',
      ambient_threshold:  50.0,
      power:              3.0
    },
    electrical_heating: {
      title: 'Electrical heating',
    },
    kitchen: {  # 1 all three of these - time of day rathern than 2010
      title: 'Kitchen',
      editable:                     [:power],
      start_time:  Time.new(2010,  1,  1,  5, 30, 0), # Ruby doesn't have a time class, just DateTime, so the 2010/1/1 should be ignored
      end_time:    Time.new(2010,  1,  1,  17, 0, 0), # ditto
      power:       4.0 #
    },
    summer_air_conn: { # 1 set power to zero for no aie conn
      title: 'Summer air conditioning',
      start_time:               Time.new(2010,  1,  1,  5, 30, 0), # Ruby doesn't have a time class, just DateTime, so the 2010/1/1 should be ignored
      end_time:                 Time.new(2010,  1,  1,  17, 0, 0), # ditto
      weekends:                 true,
      holidays:                 false,
      balancepoint_temperature: 19, # centigrade
      power_per_degreeday:      0.5 # colling degree days > balancePointTemperature
    },
    electric_hot_water: {
      title: 'Electric hot water',
      start_time:               Time.new(2010, 1, 1, 9, 0, 0), # Ruby doesn't have a time class, just DateTime, so the 2010/1/1 should be ignored
      end_time:                 Time.new(2010, 1, 1, 16, 30, 0), # ditto
      weekends:                 true,
      holidays:                 false,
      percent_of_pupils:        0.5, # often a its only a proportion of the pupils at a school has electric hot water, the rest are provided by ga
      litres_per_day_per_pupil: 5.0, # assumes at 38C versus ambient of 15C, to give a deltaT of 23C
      standby_power:            0.1 # outside start and end times, but dependent on whether switched off during weekends and holidays, see other parameters
    },
    flood_lighting:  {
      title: 'Flood lighting',
    },
    unaccounted_for_baseload: {
      title: 'Unaccounted for baseload',
      editable: [:baseload],
      baseload: 1 # 1 single number - useful
    },
    solar_pv: {
      title: 'Solar PV'
    }
  }

  def self.new
    APPLIANCE_DEFINITIONS.deep_dup
  end
end
