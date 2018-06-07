# Files in dashboard directory
%w(
half_hourly_data
aggregator
alerts
amr_data
benchmark_metrics
boiler_control
building_heat_hw_simulator
chart_manager
datetime_helper
electricity_simulator
excel_charts
holidays
load_amr_csv_for_testing
load_amr_from_bath_hacked
models
report_manager
schedule_data_manager
school_factory
series_data_manager
solar_irradiance
solar_pv
temperatures
validate_amr_data
x_axis_bucketor
y_axis_scaling
yahoo_weather_forecast
).each do |file|
  require_relative "dashboard/#{file}.rb"
end

# Ultimately based on AR models
require_relative '../app/models/school'
require_relative '../app/models/building'
require_relative '../app/models/meter'

# From gems
require 'logger'
require 'net/http'
require 'json'
require 'date'
require 'awesome_print'

require 'interpolate'
require 'benchmark'
require 'date'
require 'open-uri'
require 'logger'
require 'statsample'

require 'html-table'

require 'active_support'
require 'active_support/core_ext/date/calculations'
require 'active_support/core_ext/numeric/conversions'

# downloadregionalsolardatafromsheffieldluniversity
# downloadSolarAndTemperatureData
