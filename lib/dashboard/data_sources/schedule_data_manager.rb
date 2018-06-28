# Schedule data manager - temporary class to lazy load schedule data based on 'area' lookup
#                       - the 'areas' and lookup don;t exist for the moment (PH 14May2018)
#                       - but the initention is to consolidate the (CSV) data loading process
#                       - into a single location, so it can evenutally be replaced/supplemented
#                       - by a SQL loading process
#
# supported schedules are: holidays, temperatures, solar insolance, solar PV
class ScheduleDataManager
  # rubocop:disable Style/ClassVars
  @@holiday_data = {} # all indexed by area
  @@temperature_data = {}
  @@solar_irradiance_data = {}
  @@solar_pv_data = {}
  # rubocop:enable Style/ClassVars
  BATH_AREA_NAME = 'Bath'.freeze
  INPUT_DATA_DIR = File.join(File.dirname(__FILE__), '../../../InputData/')

  def self.holidays(area_name = nil, calendar_id = nil)
    unless @@holiday_data.key?(area_name) # lazy load data if not already loaded
      hol_data = HolidayData.new
      if calendar_id
        Calendar.find(calendar_id).holidays.map do |holiday|
          hol_data << SchoolDatePeriod.new(:holiday, holiday.title, holiday.start_date, holiday.end_date)
        end
      else
        check_area_name(area_name)
        HolidayLoader.new("#{INPUT_DATA_DIR}/Holidays.csv", hol_data)
        puts "Loaded #{hol_data.length} holidays"
      end
      hols = Holidays.new(hol_data)
      @@holiday_data[area_name] = hols
    end
    # Always return cache
    @@holiday_data[area_name]
  end

  def self.process_feed_data(output_data, data_feed_type, area_id, feed_type)
    data_feed = DataFeed.find_by(type: data_feed_type, area_id: area_id)

    query = <<-SQL
      SELECT date_trunc('day', at) AS day, array_agg(value ORDER BY at ASC) AS values
      FROM data_feed_readings
      WHERE feed_type = #{DataFeedReading.feed_types[feed_type]}
      AND data_feed_id = #{data_feed.id}
      GROUP BY date_trunc('day', at)
      SQL

    result = ActiveRecord::Base.connection.execute(query)
    result.each do |row|
      output_data.add(Date.parse(row["day"]), row["values"].delete('{}').split(',').map(&:to_f))
    end
  end

  def self.temperatures(area_name = nil, temperature_area_id = nil)

    unless @@temperature_data.key?(area_name) # lazy load data if not already loaded

      temp_data = Temperatures.new('temperatures')
      if temperature_area_id
        process_feed_data(temp_data, "DataFeeds::WeatherUnderground", temperature_area_id, :temperature)
      else
        check_area_name(area_name)
        TemperaturesLoader.new("#{INPUT_DATA_DIR}/temperatures.csv", temp_data)
        puts "Loaded #{temp_data.length} days of temperatures"
      end

      # temp_data is an object of type Temperatures
      @@temperature_data[area_name] = temp_data
    end
    @@temperature_data[area_name]
  end

  def self.solar_irradiation(area_name = nil, solar_irradiance_area_id = nil)
    unless @@solar_irradiance_data.key?(area_name) # lazy load data if not already loaded
      solar_data = SolarIrradiance.new('solar irradiance')
      if solar_irradiance_area_id
        process_feed_data(solar_data, "DataFeeds::WeatherUnderground", solar_irradiance_area_id, :solar_irradiation)
      else
        check_area_name(area_name)
        SolarIrradianceLoader.new("#{INPUT_DATA_DIR}/solarirradiation.csv", solar_data)
        puts "Loaded #{solar_data.length} days of solar irradiance data"
      end
      @@solar_irradiance_data[area_name] = solar_data
    end
    @@solar_irradiance_data[area_name]
  end

  def self.solar_pv(area_name = nil, solar_pv_tuos_area_id = nil)
    unless @@solar_pv_data.key?(area_name) # lazy load data if not already loaded
      solar_data = SolarPV.new('solar pv')
      if solar_pv_tuos_area_id
        process_feed_data(solar_data, "DataFeeds::SolarPvTuos", solar_pv_tuos_area_id, :solar_pv)
      else
        check_area_name(area_name)
        SolarPVLoader.new("#{INPUT_DATA_DIR}/pv data Bath.csv", solar_data)
        puts "Loaded #{solar_data.length} days of solar pv data"
      end

      @@solar_pv_data[area_name] = solar_data
    end
    @@solar_pv_data[area_name]
  end

  def self.check_area_name(area_name)
    unless area_name == BATH_AREA_NAME
      raise 'Loading this data for other areas is not implemented yet'
    end
  end
end
