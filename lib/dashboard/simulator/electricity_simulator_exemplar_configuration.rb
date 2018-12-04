class ElectricitySimulator
  # return configuration for an exemplar school
  def exemplar(config)
    config = config.deep_dup

    config[:lighting][:lumens_per_watt] = 100 # LEDs
    config[:lighting][:lumens_per_m2] = 300

    fit_ict(config)
    config[:ict][:servers][:number] = 1 # assume cloud server support
    config[:ict][:servers][:power_watts_each] = 150
    desktops = config[:ict][:desktops][:number]
    config[:ict][:desktops][:number] = 0
    config[:ict][:laptops][:number] += desktops
    config[:ict][:laptops][:power_watts_each] = 20

    config[:security_lighting][:control_type] = :movement_sensor

    config[:electrical_heating][:fixed_power] = 0.0
    config[:electrical_heating][:power_per_degreeday] = 0.0

    config[:kitchen][:start_time] = TimeOfDay.new(11, 0)
    config[:kitchen][:end_time] = TimeOfDay.new(12, 30)
    config[:kitchen][:average_refridgeration_power] = (250 + 250 + 350) / (365 * 24)
    config[:kitchen][:warming_oven_power] = 1.5
    config[:kitchen][:warming_oven_end_time] = TimeOfDay.new(12, 30)

    config[:summer_air_conn][:power_per_degreeday] = 0.0

    config[:electric_hot_water][:percent_of_pupils] = 100.0 # i.e. point of use, not gas
    config[:electric_hot_water][:standby_power] = 0.05
    config[:electric_hot_water][:weekends] = false
    config[:electric_hot_water][:holidays] = false

    config[:boiler_pumps][:pump_power] = 0.25 * (@school.floor_area / 1000.0)
    config[:boiler_pumps][:weekends] = false
    config[:boiler_pumps][:holidays] = false

    config[:flood_lighting][:power] = 0.0

    config[:unaccounted_for_baseload][:baseload] = 0.5 * (@school.floor_area / 1000.0)

    storeys = @school.school_type == :secondary ? 2 : 1
    # about 6m2/kWp, so 15kWp =  ~100m2, or perhaps 10% of roof area for the suggested 15kWp per 1000m2 below
    config[:solar_pv][:kwp] = (15 * (@school.floor_area / 1000.0) / storeys).round

    config
  end
end

class SimpleExemplarElectricalSimulator < ElectricitySimulator
  def initialize(school)
  end

  def floor_area
    1000.0 # school.floor_area
  end

  def number_of_pupils
    200 # school.number_of_pupils
  end

  def solar_pv_installation
    nil # @existing_electricity_meter.solar_pv_installation
  end

  def storage_heater_config
    nil # @existing_electricity_meter.storage_heater_config
  end

  def simulation_start_date
    Date.new(2017,9,1) # @period.start_date
  end

  def simulation_end_date
    Date.new(2018,9,10) # @period.end_date
  end
end
