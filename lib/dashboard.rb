require_rel '../lib/dashboard/logging'
require 'require_all'

# Ultimately based on AR models
require_rel '../app/**/*.rb'

# load all ruby files in the directory "lib" and its subdirectories
require_rel '../lib/dashboard/charting_and_reports/interpret_chart.rb'
require_rel '../lib/dashboard/**/*.rb'

# From gems
require 'logger'
require 'net/http'
require 'json'
require 'date'
require 'amazing_print'

require 'interpolate'
require 'benchmark'
require 'open-uri'
require 'statsample'

require 'html-table'

require 'active_support'
require 'active_support/core_ext/date/calculations'
require 'active_support/core_ext/numeric/conversions'
require 'active_support/core_ext/object/deep_dup'

# downloadregionalsolardatafromsheffieldluniversity
# downloadSolarAndTemperatureData

