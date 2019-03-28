
require 'benchmark'

reports = 40
years = 0.75
hours = 75

loops = reports * years * 365 * 75
loops = loops.to_i

puts "loops #{loops}"

bm = Benchmark.measure {
  loops.times do |i|
    i = i * 1.1
  end
}

puts "loop #{bm.to_s}"

bm = Benchmark.measure {
  z = 0.556
  loops.times do |i|
    x = [:ddd, :rrr, :zzz, :aaa, :bbb, :sss][i % 6]
    if x == :ddd
      z += 1
    elsif x == :rrr
      z += 2
    elsif x == :zzz
      z += 3
    elsif x == :aaa
      z += 4
    elsif x == :bbb
      z += 5
    elsif x == :sss
      z += 6
    end
  end
}

puts "if #{bm.to_s}"

bm = Benchmark.measure {
  z = 0.556
  loops.times do |i|
    x = [:ddd, :rrr, :zzz, :aaa, :bbb, :sss][i % 6]
    case x
    when :ddd
      z += 1
    when :rrr
      z += 2
    when :zzz
      z += 3
    when :aaa
      z += 4
    when :bbb
      z += 5
    when :sss
      z += 6
    end
  end
}

puts "if #{bm.to_s}"

a = Array.new(48, 6.7)
b = Array.new(48, 5.7)

bm = Benchmark.measure {
  loops.times do |i|
    a.zip(b).map{|x, y| x * y}
  end
}
puts "array multiply zip method #{bm.to_s}"

bm = Benchmark.measure {
  loops.times do |i|
    [a,b].transpose.map {|z| z.inject(:*)}
  end
}
puts "array multiply transpose map method #{bm.to_s}"

q = []

bm = Benchmark.measure {
  loops.times do |i|
    q = a.map.with_index{ |x, i| a[i]*b[i]}
  end
}
puts "array multiply with index method #{bm.to_s} #{q.sum}"

bm = Benchmark.measure {
  loops.times do |i|
    q = a.map.with_index{ |x, i| x*b[i]}
  end
}
puts "array multiply with index carry value method #{bm.to_s}  #{q.sum}"

bm = Benchmark.measure {
  loops.times do |i|
    a.size.times.collect { |i| a[i] * b[i] }
  end
}
puts "array multiply collect method #{bm.to_s}"

bm = Benchmark.measure {
  loops.times do |i|
    c = Array.new(48)
    (0..47).each { |i| c[i] = a[i] * b[i] }
  end
}
puts "array multiply i loop #{bm.to_s}"

bm = Benchmark.measure {
  loops.times do |i|
    c = Array.new(48, 0.0)
    (0..47).each { |x| c[x] = a[x] * b[x] }
  end
}
puts "array multiply i loop zeroed array #{bm.to_s}"

bm = Benchmark.measure {
  loops.times do |i|
    c = []
    (0..47).each { |i| c.push(a[i] * b[i]) }
  end
}
puts "array multiply i loop with push #{bm.to_s}"

bm = Benchmark.measure {
  loops.times do |i|
    c = Array.new(48,0.0)
    (0..47).each do |i|
      c[i] = a[i] * b[i]
    end
  end
}
puts "array multiply i loop zeroed array multi line #{bm.to_s}"

bm = Benchmark.measure {
  loops.times do |i|
    c = Array.new(48, 0.0)
    (0..47).each { |i| c[i] = a[i] + b[i] }
  end
}
puts "array addition i loop zeroed array #{bm.to_s}"

bm = Benchmark.measure {
  bs = 1.5
  loops.times do |i|
    c = Array.new(48, 0.0)
    (0..47).each { |i| c[i] = a[i] * bs }
  end
}
puts "array scale i loop zeroed array #{bm.to_s}"

bm = Benchmark.measure {
  bs = 1.5
  loops.times do |i|
    c = a.map { |v| v * bs }
  end
}
puts "array scale map array #{bm.to_s}"
