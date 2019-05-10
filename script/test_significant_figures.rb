
require_relative '../lib/dashboard.rb'

tests = [
  [:kwh,     12345.6789,            :ks2],
  [:kwh,     12345789123.6789,      :ks2],
  [:kwh,     3.6789,                :ks2],
  [:kwh,     12345.67891111,            :accountant],
  [:kwh,     12345789123.6789111111,      :accountant],
  [:£,        3.6789,                :accountant],
  [:£,        3.6789,                :ks2],
  [:£,        3.6,                :accountant],
  [:£,        0.12567,                :ks2],
  [:£,        0.12567,                :accountant],
  [:percent,        0.017,                :ks2],
]
tests.each do |one_test|
  res = FormatEnergyUnit.format(one_test[0], one_test[1], :text, false, false, one_test[2])
  puts "#{one_test.join(';')} #{res}"
  res = FormatEnergyUnit.format(one_test[0], -1 * one_test[1], :text, false, false, one_test[2])
  puts "negative #{one_test.join(';')} #{res}"
end
