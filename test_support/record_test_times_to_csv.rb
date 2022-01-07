require 'fileutils'

class RecordTestTimes
  include Singleton

  def initialize(directory: 'Results/testtimes/')
    @directory = directory
    create_directory
    @time_log = {}
  end

  def record_time(school_name, test_type, type)
    r0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    yield
    t = Process.clock_gettime(Process::CLOCK_MONOTONIC) - r0
    log_time(school_name, test_type, type, t)
  end

  def save_csv
    puts "Saving timing results to #{filename}"
  
    CSV.open(filename, 'w') do |csv|
      @time_log.each do |school_name, data|
        data.each do |test_type, test_data|
          test_data.each do |type, seconds|
            csv << [test_type, school_name, type, seconds]
          end
        end
      end
    end
  end

  private

  def log_time(school_name, test_type, type, seconds)
    @time_log[school_name] ||= {}
    @time_log[school_name][test_type] ||= {}
    @time_log[school_name][test_type][type] = seconds
  end

  def create_directory
    FileUtils.mkdir_p @directory
  end

  def filename
    "#{@directory}test timings #{DateTime.now.strftime('%Y%m%d %H%M%S')}.csv"
  end
end
