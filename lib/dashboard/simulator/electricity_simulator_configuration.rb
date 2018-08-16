require_relative '../time_of_day.rb'
require_relative '../time_of_year.rb'


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
      editable:                 [servers: [:number, :power_watts_each, :weekends, :holidays, :air_con_overhead_pecent, :type], desktops: [:number, :power_watts_each, :weekends, :holidays, :type, :standby_watts_each], laptops: [:number, :power_watts_each, :weekends, :holidays, :type, :standby_watts_each]],
      servers: {
        editable:                 [:number, :power_watts_each, :weekends, :holidays, :air_con_overhead_percent, :type],
        type:                     :server,
        number:                   2.0,
        power_watts_each:         300.0,
        air_con_overhead_percent: 0.2
      },
      desktops: {
        editable:                     [:number, :power_watts_each, :standby_watts_each],
        type:                         :desktop,
        number:                       20,
        power_watts_each:             100,
        standby_watts_each:           10,
        usage_percent_by_time_of_day: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0.05, 0.1, 0.3, 0.5, 0.8, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0.8, 0.6, 0.4, 0.2, 0.15, 0.15, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
        weekends:                     false, # left on standby at weekends
        holidays:                     false # turned off during holidays
      },
      laptops: {
        editable:                     [:number, :power_watts_each, :standby_watts_each],
        type:                         :laptop,
        number:                       20,
        power_watts_each:             30,
        standby_watts_each:           2,
        usage_percent_by_time_of_day: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0.05, 0.1, 0.3, 0.5, 0.8, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0.8, 0.6, 0.4, 0.2, 0.15, 0.15, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
        weekends:                     false, # left on standby at weekends
        holidays:                     false # turned off during holidays
      }
    },
    security_lighting: {
      title: 'Security lighting',
      editable:           [:power, :control_type, :fixed_start_time, :fixed_end_time, :power, :ambient_threshold],
      control_type:       :sunrise_sunset,
      control_type_choices: [:sunrise_sunset, :ambient, :fixed_times, :movement_sensor],
      sunrise_times:      ['08:05', '07:19', '06:19', '06:10', '05:14', '04:50', '05:09', '05:54', '06:43', '07:00', '07:26', '08:06'], # by month - in string format as more compact than new Time - which it needs converting to
      sunset_times:       ['16:33', '17:27', '18:16', '20:08', '20:56', '21:30', '21:21', '20:32', '19:24', '18:17', '16:21', '16:03'], # ideally front end calculates based on GEO location
      fixed_start_time:   '19:15',
      fixed_end_time:     '07:20',
      ambient_threshold:  50.0,
      power:              3.0
    },
    electrical_heating: {
        title: 'Electrical heating',
        editable:                 [:fixed_power, :power_per_degreeday, :start_time, :end_time, :balancepoint_temperature :weekends, :holidays],
        start_time:               TimeOfDay.new(8, 30),
        end_time:                 TimeOfDay.new(17, 0),
        fixed_power:              4.0,
        weekends:                 false,
        holidays:                 false,
        balancepoint_temperature: 15.5, # centigrade
        power_per_degreeday:      0.25 # kW/C
    },
    kitchen: {
      title: 'Kitchen',
      editable:                 [:power, :start_time, :end_time, :average_refridgeration_power, :warming_oven_power, :warming_oven_start_time, :warming_oven_end_time],
      start_time:               TimeOfDay.new(8, 0),
      end_time:                 TimeOfDay.new(13, 0),
      power:                    3.0,
      average_refridgeration_power: 0.4,
      warming_oven_power:          2.0,
      warming_oven_start_time:    TimeOfDay.new(11, 30),
      warming_oven_end_time:      TimeOfDay.new(13, 0)
    },
    summer_air_conn: { # 1 set power to zero for no air conn
      title: 'Summer air conditioning',
      editable:                 [:weekends, :start_time, :end_time, :holidays, :balancepoint_temperature, :power_per_degreeday],
      start_time:               TimeOfDay.new(5, 30),
      end_time:                 TimeOfDay.new(23, 30),
      weekends:                 true,
      holidays:                 true,
      balancepoint_temperature: 16, # centigrade
      power_per_degreeday:      0.4 # cooling degree days > balancePointTemperature
    },
    electric_hot_water: {
      title: 'Electric hot water',
      editable:                 [:weekends, :start_time, :end_time, :holidays, :percent_of_pupils, :litres_per_day_per_pupil, :standby_power],
      start_time:               TimeOfDay.new(9, 0),
      end_time:                 TimeOfDay.new(16, 30),
      weekends:                 true,
      holidays:                 false,
      percent_of_pupils:        50.0, # often a its only a proportion of the pupils at a school has electric hot water, the rest are provided by ga
      litres_per_day_per_pupil: 5.0, # assumes at 38C versus ambient of 15C, to give a deltaT of 23C
      standby_power:            0.1 # outside start and end times, but dependent on whether switched off during weekends and holidays, see other parameters
    },
    boiler_pumps: {
      title: 'Boiler pumps',
      editable:                     [:pump_power, :start_time, :end_time, :weekends, :holidays, :frost_protection_temp],
      start_time:                   TimeOfDay.new(5, 30),
      end_time:                     TimeOfDay.new(17, 0),
      pump_power:                   0.5, # 1 kw
      weekends:                     false,
      holidays:                     true,
      boiler_gas_power_on_criteria: 15.0,
      frost_protection_temp:        4
    },
    flood_lighting:  {
      title: 'Flood lighting',
      editable:                 [:power, :ambient_light_threshold, bookings: [:weekday, :start_time, :end_time, :holidays, :start_date, :end_date]],
      power:    35.0,
      ambient_light_threshold: 200, # lumens/m2
      bookings: [
        {
          weekday:      2,
          start_time:   TimeOfDay.new(18, 30),
          end_time:     TimeOfDay.new(20, 15),
          holidays:     false,
          start_date:   TimeOfYear.new(10, 1),
          end_date:     TimeOfYear.new(3, 30)
        },
        {
          weekday:      0,
          start_time:   TimeOfDay.new(18, 0),
          end_time:     TimeOfDay.new(19, 20),
          holidays:     true,
          start_date:   TimeOfYear.new(2, 22),
          end_date:     TimeOfYear.new(5, 10)
        }
      ]
    },
    unaccounted_for_baseload: {
      title: 'Unaccounted for baseload',
      editable: [:baseload],
      baseload: 1.0 # 1 single number - useful
    },
    solar_pv: {
      title: 'Solar PV',
      editable: [:kwp],
      kwp:  4.0
    }
  }

  def self.new
    APPLIANCE_DEFINITIONS.deep_dup
  end
end