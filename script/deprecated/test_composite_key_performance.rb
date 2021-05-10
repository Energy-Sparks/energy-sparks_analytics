require 'memory_profiler'
require 'benchmark'
require 'date'

start_date = Date.new(2010,1,1)
end_date = Date.new(2021,1,1)


def simple_keys(start_date, end_date)
  data = {}
  (start_date..end_date).each do |date|
    data[date] = {
      kwh_x48: Array.new(48, 0.0),
      rates:  {
                rate0_tiered_1111: 10.0,
                rate1_tiered_1111: 11.0,
                rate2_tiered_1111: 12.0
      }
    }
  end
  data
end

def composite_keys(start_date, end_date)
  data = {}
  (start_date..end_date).each do |date|
    data[date] = {
      kwh_x48: Array.new(48, 0.0),
      rates:  {
                { type: :rate0, time: Date.new(2011,1,1)..Date.new(2012,1,1) } => 10.0, 
                { type: :rate1, time: Date.new(2011,1,1)..Date.new(2012,1,1) } => 11.0,
                { type: :rate2, time: Date.new(2011,1,1)..Date.new(2012,1,1) } => 12.0
      }
    }
  end
  data
end

def composite_keys2(start_date, end_date)
  uniq = {}
  k1 = { type: :rate0, time: '10:00' }
  k2 = { type: :rate1, time: '10:00' }
  k3 = { type: :rate2, time: '10:00' }
  uniq[k1.to_a.flatten.map(&:to_s).join('_')] = k1
  uniq[k2.to_a.flatten.map(&:to_s).join('_')] = k2
  uniq[k3.to_a.flatten.map(&:to_s).join('_')] = k3
  data = {}
  (start_date..end_date).each do |date|
    data[date] = {
      kwh_x48: Array.new(48, 0.0),
      rates:  {
        uniq.key({ type: :rate0, time: '10:00' }) => 10.0,
        uniq.key({ type: :rate1, time: '10:00' }) => 11.0,
        uniq.key({ type: :rate2, time: '10:00' }) => 12.0
      }
    }
  end
  data
end

def composite_keys3(start_date, end_date)
  uniq = {}
  data = {}
  (start_date..end_date).each do |date|
    k1 = "#{'rate'}#{'0'}".to_sym.freeze
    k2 = "#{'rate'}#{'0'}".to_sym.freeze
    k3 = "#{'rate'}#{'0'}".to_sym.freeze
    data[date] = {
      kwh_x48: Array.new(48, 0.0),
      rates:  {
        k1 => 10.0,
        k2 => 11.0,
        k3 => 12.0
      }
    }
  end
  data
end

t = 0
s = 0
10.times do
  report = MemoryProfiler.report do
    simple_keys(start_date, end_date)
  end

  bm = Benchmark.realtime {
    d = simple_keys(start_date, end_date)
    2000.times { s += d[Date.new(2015,1,1)][:rates][:rate0_tiered_1111]}
  }
  t += bm
  puts "Simple: #{bm.round(6)} seconds #{report.total_allocated_memsize} bytes"
end
puts "Simple 10x = #{t.round(3)}  #{s.round(0)}"

t = 0
s = 0 
10.times do
  report = MemoryProfiler.report do
    composite_keys(start_date, end_date)
  end

  bm = Benchmark.realtime {
    d = composite_keys(start_date, end_date)
    2000.times { s += d[Date.new(2015,1,1)][:rates][{ type: :rate0, time: Date.new(2011,1,1)..Date.new(2012,1,1) }]}
  }
  t += bm
  puts "Complex: #{bm.round(6)} seconds #{report.total_allocated_memsize} bytes"
end
puts "Complex: 10x = #{t.round(3)} #{s.round(0)}"

t = 0
s = 0 
10.times do
  report = MemoryProfiler.report do
    composite_keys2(start_date, end_date)
  end

  bm = Benchmark.realtime {
    d = composite_keys2(start_date, end_date)
    2000.times { s += d[Date.new(2015,1,1)][:rates]['type_rate0_time_10:00'] }
  }
  t += bm
  puts "Complex 2: #{bm.round(6)} seconds #{report.total_allocated_memsize} bytes"
end
puts "Complex 2: 10x = #{t.round(3)} #{s.round(0)}"

t = 0
s = 0 
10.times do
  report = MemoryProfiler.report do
    composite_keys3(start_date, end_date)
  end

  bm = Benchmark.realtime {
    d = composite_keys3(start_date, end_date)
    2000.times { s += d[Date.new(2015,1,1)][:rates]['rate0'.to_sym] }
  }
  t += bm
  puts "Complex 3: #{bm.round(6)} seconds #{report.total_allocated_memsize} bytes"
end
puts "Complex 3: 10x = #{t.round(3)} #{s.round(0)}"

