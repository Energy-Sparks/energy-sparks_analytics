# test report manager
require 'require_all'
require_relative '../lib/dashboard.rb'
require_rel '../test_support'
require './script/report_config_support.rb'

module Logging
  @logger = Logger.new('log/test-equivalances ' + Time.now.strftime('%H %M') + '.log')
  logger.level = :debug
end

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
  'Electricity kWh to teaching assistant (hours)' => [10_000.0, :kwh, :electricity, :teaching_assistant, :teaching_assistant, :£]
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
