require_relative './building_heat_hw_simulator.rb'
require_relative './building_heat_balance_simulator_configuration.rb'
# Energy Balance Building Simulation Model
# ========================================
# Purpose
# - investigate impact of COVID on schools: lack of occupancy (pupil, electrical gain) versus additional controlled ventilation loss
# - tracking and targetting - can it be used to help intraday gas targets, are they necessary?
# - additional alerts: better thermostatic control, ventilation impacts, temperature impacts, -tve HW impact, changes in insulation, MVHR
# - research: better understanding of gains versus losses, understanding of under-performing schools
# - precursor to inverse lumped parameter model
# Outputs
# - generic chart based energy balance - gains versus losses - reuse electrical simulation framework
# - sensitivity to ventilation, occupancy, sunshine
# Improvements
# - include totals in csv output
# - write to xlxs
# - take generic description of school - e.g. U values, form factor, window area, default any missing
# - back test against regression model - can it produce better CUSUM?
# - fitting: as per lumped parameter model: imply thermal mass and U values? Can thermal mass be implied from Mon -> Fri regression
# - air and admittance model, optimum start, identify schools where gas consumption should decline during day but don't
# - new charts for splitting heating versus hot water in main stream code base
# - frost protection analysis
# - predicted daily versus regression versus actual
# Questions
# - is a sub 30 minute frequency required?
require 'write_xlsx'

class BuildingHeatBalanceSimulator < BuildingHeatHWSimulator

  def create_empty_amr_datasets(list_of_types)
    @amr_result_datasets = {}
    list_of_types.each do |type|
      @amr_result_datasets[type] = AMRData.create_empty_dataset(type, @simulation_start_date, @simulation_end_date)
    end
  end

  def set_result(type, date, half_hour_index, kwh)
    @amr_result_datasets[type].set_kwh(date, half_hour_index, kwh)
  end

  def save_to_csv
    filename = 'Results\building heat balance results.csv'
    puts "Saving readings to #{filename}"
    CSV.open(filename, 'w') do |csv|
      csv << ['date', 'half hour', @amr_result_datasets.keys.map{ |key| key.to_s.humanize }].flatten
      (simulation_start_date..simulation_end_date).each do |date|
        (0...simulations_per_day).each do |simulation_day_index|
          sdi = simulation_day_index # for brevity
          hhi = simulation_index_to_halfhour_index(simulation_day_index)
          results = @amr_result_datasets.values.map{ |amr| amr.kwh(date, hhi) }
          csv << [date, hhi, results].flatten
        end
      end
    end
  end

  def save_to_excel
    filename = 'Results\building heat balance results - complex.xlsx'
    workbook = WriteXLSX.new(filename)
    worksheet = workbook.add_worksheet('data')

    # Write a formatted and unformatted string, row and column notation.
    col = row = 0
    worksheet.write(0, 0, ['date', 'half hour', 'dt', @amr_result_datasets.keys.map{ |key| key.to_s.humanize }].flatten)
    (simulation_start_date..simulation_end_date).each_with_index do |date, date_index|
      (0...simulations_per_day).each_with_index do |simulation_day_index, hhi|
        row = 1 + date_index * 48 + hhi
        results = @amr_result_datasets.values.map{ |amr| amr.kwh(date, simulation_day_index) }
        worksheet.write(row, 0, [date, hhi, DateTimeHelper.datetime(date, hhi), results].flatten)
      end
    end

    worksheet = workbook.add_worksheet('daily')
    worksheet.write(0, 0, ['date', 'occupied', 'outside temperature', 'actual', 'simulated', 'regression'])
    (simulation_start_date..simulation_end_date).each_with_index do |date, date_index|
      results = [
        date,
        occupied?(date),
        @school.temperatures.average_temperature(date),
        @amr_result_datasets[:actual_heating_hw].one_day_total(date),
        @amr_result_datasets[:heating_gain].one_day_total(date),
        @heating_model.predicted_kwh(date, @school.temperatures.average_temperature(date))
      ]
      worksheet.write(1 + date_index, 0, results)
    end

    worksheet = workbook.add_worksheet('totals')
    @amr_result_datasets.each_with_index do |(type, amr_kwh), index|
      worksheet.write(index, 0, [type.to_s.humanize, amr_kwh.total])
    end

    workbook.close
  end

  def datetime(date, hhi)
    DateTime.new
  end

  def default_simulation_control
    {
      heating: {
        on:     :follow_actual_boiler_on,
        timing: :follow_actual_boiler_timing
      }
    }
  end

  def heating_on?(control, date, halfhour_index)
    if control.dig(:heating, :on) == :follow_actual_boiler_on
      if control.dig(:heating, :timing) == :follow_actual_boiler_timing
        @heating_model.heating_on?(date) && @heating_model.heating_on_date_time?(date, halfhour_index)
      else
        @heating_model.heating_on?(date) && occupied_by_time?(date, halfhour_index)
      end
    else
      occupied_date_time?(date, sdi)
    end
  end

  def run_simulation
    create_log

    control = default_simulation_control

    puts "Here:"
    config =  BuildingHeatBalanceSimulatorConfiguration.school_config(@school)
    puts config.wall_heat_loss_w_per_k
    puts "Ends:"
    hw = HotWaterHeatingSplitter.new(@school)
    split_hw_heat_amr = hw.split_heat_and_hot_water(simulation_start_date, simulation_end_date)
    actual_heating_only_amr = split_hw_heat_amr[:heating_only_amr]
    actual_hot_water_only_amr= split_hw_heat_amr[:hot_water_only_amr]

    log_calculations = true

    if log_calculations
      amr_types = %i[time occupied external_temperature internal_temperature delta_t temperature_change pupil_gain electrical_gain solar_gain heating_gain hotwater_gain actual_heating_hw total_gain
                      wall_loss window_loss controlled_ventilation_loss uncontrolled_ventilation_loss total_losses net_loss predicted_gas hw_only heating_only]
      create_empty_amr_datasets(amr_types)
    end

    model_period = SchoolDatePeriod.new(:heat_balance_simulation, 'Current Year', simulation_start_date, simulation_end_date)
    @heating_model = school.aggregated_heat_meters.heating_model(model_period)

    internal_temperature = @temperatures.temperature(simulation_start_date, 0) # assume internal temp = external on first day
    wall_temp = internal_temperature

    @super_debug = false

    bm = Benchmark.realtime {

    puts "Wall area for thermal mass: #{total_internal_external_wall_area}"
    puts "Mass = #{thermal_mass_building_kwh_per_k} kWh per K"

    (simulation_start_date..simulation_end_date).each do |date|
      (0...simulations_per_day).each do |simulation_day_index|
        sdi = simulation_day_index # for brevity
        hhi = simulation_index_to_halfhour_index(simulation_day_index)

        occupied = occupied_date_time?(date, sdi)

        external_temperature = @temperatures.temperature(date, simulation_index_to_halfhour_index(sdi))

        delta_t = internal_temperature - external_temperature

        if heating_on?(control, date, hhi) && internal_temperature < set_point_temperature
          heating_gain_kwh = 0.8 * 70.0 / 2.0 # 80% boiler efficiency, rough 70 kW peak at Bathampton
        else
          heating_gain_kwh = 0.0
        end

        hw_only       = split_hw_heat_amr[:hot_water_only_amr].kwh(date, hhi)
        heating_only  = split_hw_heat_amr[:heating_only_amr].kwh(date, hhi)

       # @hw_kwh_tod = { 13 => 32.0, 14 => 22.0, 15 => 13.0, 16 => 13.0, 17 => 11.0, 18 => 8, 19 => 9 }
        
        # hotwater_gain_kwh = (occupied && @hw_kwh_tod.key?(hhi) ? @hw_kwh_tod[hhi] : 0.0) * 0.8
        hotwater_gain_kwh = (occupied ? actual_hot_water_only_amr.kwh(date, hhi) : 0.0) * 0.8
        predicted_gas_kwh = (heating_gain_kwh + hotwater_gain_kwh) / 0.8

        pupil_gain_kwh      = pupil_gain_kw(date, sdi) / 2.0
        solar_gain_kwh      = solar_gain_kw(date, sdi) / 2.0
        electrical_gain_kwh = electrical_gain_kw(date, sdi) / 2.0
        total_gain_kwh      = pupil_gain_kwh + solar_gain_kwh + electrical_gain_kwh + heating_gain_kwh + hotwater_gain_kwh

        gains_kw = total_gain_kwh * 2.0

        fabric_loss_kw = fabric_loss_kw_per_k * delta_t
        controlled_ventilation_loss_kw   = air_heat_loss_kw(controlled_air_permeability_m3_per_hr(date, sdi), delta_t)
        uncontrolled_ventilation_loss_kw = air_heat_loss_kw(uncontrolled_air_permeability_m3_per_hr(date, sdi), delta_t)
        losses_kw = fabric_loss_kw + controlled_ventilation_loss_kw + uncontrolled_ventilation_loss_kw

        net_gain_kw = gains_kw - losses_kw

        if log_calculations
          set_result(:occupied,                       date, hhi, occupied ? 1.0 : 0.0)
          set_result(:external_temperature,           date, hhi, external_temperature)
          set_result(:delta_t,                        date, hhi, delta_t)
          set_result(:pupil_gain,                     date, hhi, pupil_gain_kwh)
          set_result(:solar_gain,                     date, hhi, solar_gain_kwh)
          set_result(:electrical_gain,                date, hhi, electrical_gain_kwh)
          set_result(:hotwater_gain,                  date, hhi, hotwater_gain_kwh)
          set_result(:total_gain,                     date, hhi, total_gain_kwh)
          set_result(:heating_gain,                   date, hhi, heating_gain_kwh) 
          set_result(:wall_loss,                      date, hhi, fabric_loss_kw / 2.0)
          set_result(:window_loss,                    date, hhi, 0.0)
          set_result(:controlled_ventilation_loss,    date, hhi, controlled_ventilation_loss_kw / 2.0)
          set_result(:uncontrolled_ventilation_loss,  date, hhi, uncontrolled_ventilation_loss_kw / 2.0)
          set_result(:total_losses,                   date, hhi, losses_kw / 2.0)
          set_result(:net_loss,                       date, hhi, - net_gain_kw / 2.0)
          set_result(:predicted_gas,                  date, hhi, predicted_gas_kwh)
          set_result(:actual_heating_hw,              date, hhi, actual_heating_kw(date, hhi) / 2.0)
          set_result(:hw_only,                        date, hhi, hw_only)
          set_result(:heating_only,                   date, hhi, heating_only)
        end

        change_in_thermal_mass_k = net_gain_kw / thermal_mass_building_kwh_per_k / 2.0 # 2.0 needs changing in non hald hour simulation
        internal_temperature += change_in_thermal_mass_k

        if log_calculations
          set_result(:temperature_change,   date, sdi, change_in_thermal_mass_k)
          set_result(:internal_temperature, date, hhi, internal_temperature)
        end

        if @super_debug
          log(:occupied,                          date, sdi, occupied)
          log(:external_temperature,              date, sdi, external_temperature)
          log(:internal_temperature,              date, sdi, internal_temperature)
         
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
    }
    puts "Simulation took #{bm.round(5)}"
    save_raw_data_to_csv_for_debug('building simulator debug.csv', create_meta_data_log) if @super_debug

    puts "logging #{log_calculations}"
    save_to_csv if log_calculations
    save_to_excel if log_calculations
  end

  private def create_meta_data_log
    {
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
  end
end

# Performance tuning log: PH 6Jun2020
# @super_debug = false; 0.47S
# @super_debug = false; TimeOfDay: Time => DateTime; 0.21S
# ditto, cache admittance calc; 0.24S
# electric real amr data; 0.30S
# pupil gain cache floor area calc: 0.18S
# ditto, cache occupied?: 0.16
# ditto; cache occupied date and time: 0.17
# ditto; cache fabric calc: 0.16
# ditto; cache time of day index: 0.12
# ditto; cache thermal mass and uncontrolled vent calc: 0.11

# thoughts on objectives for new model and how to refine 30Jul2020
# its purpose is to explore the impact of:
# - solar, electrical, occupancy gain
# - controlled air permability and other fabric losses
# - thermal mass, particularly over weekends