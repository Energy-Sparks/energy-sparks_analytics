# test report manager
require 'require_all'
require_relative '../lib/dashboard.rb'
require_rel '../test_support'
require './script/report_config_support.rb'

module Logging
  @logger = Logger.new('log/test-equivalances ' + Time.now.strftime('%H %M') + '.log')
  logger.level = :debug
end

=begin
schools = ReportConfigSupport.new.schools

schools.each do |school_name, fuel_type|
  next if fuel_type == :gas_only

  meter_collection = SchoolFactory.new.load_or_use_cached_meter_collection(:name, school_name, :analytics_db)

  conversion = EnergyConversions.new(meter_collection)

  results = conversion.front_end_convert(:ice_car_kwh_km, {year: 0}, :electricity)

  puts '=' * 80
  puts school_name
  puts '=' * 80
  ap(results)
end
=end

school_name = 'Paulton Junior School'

meter_collection = SchoolFactory.new.load_or_use_cached_meter_collection(:name, school_name, :analytics_db)

conversion = EnergyConversions.new(meter_collection)

list_of_conversions = EnergyConversions.front_end_conversion_list

list_of_conversions.each do |conversion_key, conversion_configuration|
  results = conversion.front_end_convert(conversion_key, {month: -2}, :electricity)
  puts '=' * 80
  puts conversion_key
  ap(conversion_configuration)
  ap(results)
end


exit

ap(conversion.equivalences_available_to_front_end)

results = conversion.front_end_convert(:ice_car_kwh_km, {month: 0}, :electricity)
ap(results)

results = conversion.front_end_convert_2(:ice_car_kwh_km, {month: 0}, :electricity)
ap(results)

results = conversion.front_end_convert(:ice_car_co2_km, {year: 0}, :electricity)
ap(results)

list_of_conversions = conversion.front_end_conversion_list
list_of_conversions.each do |conversion_key, conversion_configuration|
  results = conversion.front_end_convert(conversion_key, {year: 0}, :electricity)
  ap(results)
end

ap(x)

exit

[:electricity, :gas].each do |fuel_type|
  [{week: 0}, {day: 0}, {month: 0}, {year: 0}].each do |period|
    [:kwh, :co2, :£].each do |convert_to|
      type_choices = conversion.conversion_choices(convert_to)
      type_choices.each do |type|
        next if [:electricity, :gas].include?(type)
        value, kwh, factor = conversion.convert(type, convert_to, period, fuel_type)
        formatted_kwh = FormatEnergyUnit.format(:kwh, kwh)
        formatted_value = FormatEnergyUnit.format(type, value)
        puts "Your school consumed #{formatted_kwh} of #{fuel_type} for period #{period} this is equivalent  #{type}: #{formatted_value} (via #{convert_to})"
      end
    end
  end
end
exit

scalar_data = ScalarkWhCO2CostValues.new(meter_collection)
bm = Benchmark.realtime {
  puts scalar_data.aggregate_value({week: 0}, :electricity, :kwh)
}
puts "kwh 1 year takes #{bm.round(5)} seconds"
bm = Benchmark.realtime {
  puts scalar_data.aggregate_value({week: 0}, :electricity, :co2)
}
puts "co2 1 year takes #{bm.round(5)} seconds"
bm = Benchmark.realtime {
  puts scalar_data.aggregate_value({week: 0}, :electricity, :£)
}
puts "pounds 1 year takes #{bm.round(5)} seconds"
exit

equivalences = {
  'Electricity kWh to petrol car via £' => [1000.0, :kwh, :electricity, :km, :ice_car, :£],
  'Electricity kWh to petrol car via CO2' => [1000.0, :kwh, :electricity, :km, :ice_car, :co2],
  'Electricity kWh to petrol car via kWh' => [1000.0, :kwh, :electricity, :km, :ice_car, :kwh],
  'Gas kWh to petrol car via £' => [1000.0, :kwh, :gas, :km, :ice_car, :£],
  'Gas kWh to petrol car via CO2' => [1000.0, :kwh, :gas, :km, :ice_car, :co2],
  'Gas kWh to petrol car via kWh' => [1000.0, :kwh, :gas, :km, :ice_car, :kwh],
  'Electricity kWh to homes via kWh' => [100_000.0, :kwh, :electricity, :home, :home, :kwh],
  'Electricity kWh to homes via CO2' => [100_000.0, :kwh, :electricity, :home, :home, :co2],
  'Electricity kWh to homes via £' => [100_000.0, :kwh, :electricity, :home, :home, :£],
  'Gas kWh to showers via kWh' => [10_000.0, :kwh, :gas, :shower, :shower, :kwh],
  'Gas kWh to showers via CO2' => [10_000.0, :kwh, :gas, :shower, :shower, :co2],
  'Gas kWh to showers via £' => [10_000.0, :kwh, :gas, :shower, :shower, :£],
  'Electricity kWh to kettles via kWh' => [1000.0, :kwh, :electricity, :kettle, :kettle, :kwh],
  'Electricity kWh to kettles via CO2' => [1000.0, :kwh, :electricity, :kettle, :kettle, :co2],
  'Electricity kWh to kettles via £' => [1000.0, :kwh, :electricity, :kettle, :kettle, :£],
  'Electricity £ to kettles via £' => [1000.0, :£, :electricity, :kettle, :kettle, :£],
  'Electricity kWh to charge smartphones' => [1000.0, :kwh, :electricity, :smartphone, :smartphone, :kwh],
  'Electricity kWh to trees' => [10_000.0, :kwh, :electricity, :tree, :tree, :co2],
  'Electricity kWh to teaching assistant (hours)' => [10_000.0, :kwh, :electricity, :teaching_assistant, :teaching_assistant, :£],
  'Electricity kWh to TV hours - via £' => [10_000.0, :kwh, :electricity, :tv, :tv, :£],
  'Electricity kWh to TV hours - via co2' => [10_000.0, :kwh, :electricity, :tv, :tv, :co2],
  'Electricity kWh to TV hours - via kwh' => [10_000.0, :kwh, :electricity, :tv, :tv, :kwh],
  'Electricity kWh to electric car via £' => [1000.0, :kwh, :electricity, :km, :bev_car, :£],
  'Electricity kWh to electric car via CO2' => [1000.0, :kwh, :electricity, :km, :bev_car, :co2],
  'Electricity kWh to electric car via kWh' => [1000.0, :kwh, :electricity, :km, :bev_car, :kwh],
  'Electricity kWh to dinner with meat via £' => [1000.0, :kwh, :electricity, :carnivore_dinner, :carnivore_dinner, :£],
  'Electricity kWh to dinner with meat via CO2' => [1000.0, :kwh, :electricity, :carnivore_dinner, :carnivore_dinner, :co2],
  'Electricity kWh to vegetarian dinner via £' => [1000.0, :kwh, :electricity, :vegetarian_dinner, :vegetarian_dinner, :£],
  'Electricity kWh to vegetarian dinner via CO2' => [1000.0, :kwh, :electricity, :vegetarian_dinner, :vegetarian_dinner, :co2],
  'Electricity kWh to onshore wind turbine hours via kwh' => [100000.0, :kwh, :electricity, :onshore_wind_turbine_hours, :onshore_wind_turbine_hours, :kwh],
  'Electricity kWh to offshore wind turbine hours via kwh' => [100000.0, :kwh, :electricity, :offshore_wind_turbine_hours, :offshore_wind_turbine_hours, :kwh],
  'Electricity kWh to solar panels in a year via kwh' => [100000.0, :kwh, :electricity, :solar_panels_in_a_year, :solar_panels_in_a_year, :kwh]
}

puts
puts 'Random equivalences:'
(0..20).each do |_count|
  equiv_type, conversion_type = EnergyEquivalences.random_equivalence_type_and_via_type
  puts "    #{equiv_type}, #{conversion_type}"
end

puts 'Full fixed tests:'
equivalences.each do |name, data|
  puts '=' * 80
  puts name
  puts
  val, equivalence, calc, in_text, out_text = EnergyEquivalences.convert(data[0], data[1], data[2], data[3], data[4], data[5])
  puts
  puts equivalence
  puts "Calculation:"
  puts "#{in_text}"
  puts "#{out_text}"
  puts "#{calc}"
end
