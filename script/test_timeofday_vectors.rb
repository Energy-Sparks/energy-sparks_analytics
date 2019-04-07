# test report manager
require 'ruby-prof'
require 'require_all'
require_relative '../lib/dashboard.rb'
require_rel '../test_support'
require './script/report_config_support.rb'

time_of_day_vectors = [
   [ TimeOfDay.new(0, 0)..TimeOfDay.new(24, 0) ],
   [ TimeOfDay.new(0, 0)..TimeOfDay.new(1, 0) ],
   [ TimeOfDay.new(0, 30)..TimeOfDay.new(1, 0) ],
   [ TimeOfDay.new(0, 30)..TimeOfDay.new(1, 45) ],
   [ TimeOfDay.new(0, 45)..TimeOfDay.new(1, 0) ],
   [ TimeOfDay.new(0, 45)..TimeOfDay.new(2, 20) ],
   [ TimeOfDay.new(23, 31)..TimeOfDay.new(24, 0) ],
   [ TimeOfDay.new(0, 0)..TimeOfDay.new(6, 30) ],
   [ TimeOfDay.new(0, 30)..TimeOfDay.new(6, 00) ],
   [ TimeOfDay.new(0, 0)..TimeOfDay.new(24, 00) ],
]

times = 100000

bm = Benchmark.measure {
  times.times do |i|
    time_of_day_vectors.each do |vector|
      x = DateTimeHelper.weighted_x48_vector_multiple_ranges(vector)
      # puts vector
      # ap(x)
    end
  end
}

puts bm.to_s
