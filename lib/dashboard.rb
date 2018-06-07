# Files in dashboard directory
%w(
aggregator
alerts
halfhourlydata
amrdata
benchmarkmetrics
boilercontrol
buildingheathwsimulator
chartmanager
datetimehelper
electricitySimulator
excelcharts
holidays
loadamrcsvfortesting
loadamrdatafrombathhacked
models
reportmanager
scheduledatamanager
schoolfactory
seriesdatamanager
solarirradiance
solarpv
temperatures
validateamrdata
xaxisbucketor
yahooweatherforecast
yaxisscaling
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