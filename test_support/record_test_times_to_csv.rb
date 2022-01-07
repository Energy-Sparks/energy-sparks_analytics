require 'fileutils'

class RecordTestTimes
  def initialize(type, directory: 'Results/testtimes/')
    @directory = directory
    @type = type
    create_directory
    @time_log = {}
  end

  def record_time(school_name, type)
    r0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    yield
    t = Process.clock_gettime(Process::CLOCK_MONOTONIC) - r0
    log_time(school_name, type, t)
  end

  def save_csv
    puts "Saving results to #{filename}"
  
    CSV.open(filename, 'w') do |csv|
      @time_log.each do |school_name, data|
        data.each do |type, seconds|
          csv << [school_name, type, seconds]
        end
      end
    end
  end

  private

  def log_time(school_name, type, seconds)
    @time_log[school_name] ||= {}
    @time_log[school_name][type] = seconds
  end

  def create_directory
    FileUtils.mkdir_p @directory
  end

  def filename
    "#{@directory}#{@type} #{DateTime.now.strftime('%Y%m%d %H %M %S')}.csv"
  end
end
