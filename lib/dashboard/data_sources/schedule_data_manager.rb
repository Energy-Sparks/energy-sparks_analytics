# Schedule data manager - temporary class to lazy load schedule data based on 'area' lookup
#                       - the 'areas' and lookup don;t exist for the moment (PH 14May2018)
#                       - but the initention is to consolidate the (CSV) data loading process
#                       - into a single location, so it can evenutally be replaced/supplemented
#                       - by a SQL loading process
#
# supported schedules are: holidays, temperatures, solar insolance, solar PV
class ScheduleDataManager
  include Logging

  # rubocop:disable Style/ClassVars
  @@holiday_data = {} # all indexed by area
  @@temperature_data = {}
  @@solar_irradiance_data = {}
  @@solar_pv_data = {}
  @@uk_grid_carbon_intensity_data = nil
  # rubocop:enable Style/ClassVars
  BATH_AREA_NAME = 'Bath'.freeze
  INPUT_DATA_DIR = File.join(File.dirname(__FILE__), '../../../InputData/')

  def self.holidays(area_name = nil, calendar_id = nil)
    unless @@holiday_data.key?(area_name) # lazy load data if not already loaded
      hol_data = HolidayData.new
      if calendar_id
        Calendar.find(calendar_id).holidays.order(:start_date).map do |holiday|
          hol_data << SchoolDatePeriod.new(:holiday, holiday.title, holiday.start_date, holiday.end_date)
        end
      else
        check_area_name(area_name)

        area = AreaNames.key_from_name(area_name)
        hol_data = HolidayData.new
        filename = self.full_filepath(AreaNames.holiday_schedule_filename(area))
        HolidayLoader.new(filename, hol_data)
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
      ORDER BY day ASC
      SQL

    result = ActiveRecord::Base.connection.execute(query)
    result.each do |row|
      output_data.add(Date.parse(row["day"]), row["values"].delete('{}').split(',').map(&:to_f))
    end
  end


  def self.full_filepath(filename)
    "#{INPUT_DATA_DIR}/" + filename
  end

  def self.temperatures(area_name = nil, temperature_area_id = nil)
    check_area_name(area_name)

    unless @@temperature_data.key?(area_name) # lazy load data if not already loaded

      temp_data = Temperatures.new('temperatures')

      if temperature_area_id
        process_feed_data(temp_data, "DataFeeds::WeatherUnderground", temperature_area_id, :temperature)
      else
        area = AreaNames.key_from_name(area_name)
        filename = self.full_filepath(AreaNames.temperature_filename(area))
        TemperaturesLoader.new(filename, temp_data)
        puts "Loaded #{temp_data.length} days of temperatures"
      end

      # temp_data is an object of type Temperatures
      @@temperature_data[area_name] = temp_data
    end
    @@temperature_data[area_name]
  end

  def self.solar_irradiation(area_name = nil, solar_irradiance_area_id = nil)

    check_area_name(area_name)

    unless @@solar_irradiance_data.key?(area_name) # lazy load data if not already loaded

      solar_data = SolarIrradiance.new('solar irradiance')

      if solar_irradiance_area_id
        process_feed_data(solar_data, "DataFeeds::WeatherUnderground", solar_irradiance_area_id, :solar_irradiation)
      else
        area = AreaNames.key_from_name(area_name)
        filename = self.full_filepath(AreaNames.solar_irradiance_filename(area))

        SolarIrradianceLoader.new(filename, solar_data)
        puts "Loaded #{solar_data.length} days of solar irradiance data"
      end

      @@solar_irradiance_data[area_name] = solar_data
    end
    @@solar_irradiance_data[area_name]
  end

  def self.solar_pv(area_name = nil, solar_pv_tuos_area_id = nil)

    check_area_name(area_name)

    unless @@solar_pv_data.key?(area_name) # lazy load data if not already loaded

      solar_data = SolarPV.new('solar pv')

      if solar_pv_tuos_area_id
        process_feed_data(solar_data, "DataFeeds::SolarPvTuos", solar_pv_tuos_area_id, :solar_pv)
      else
        area = AreaNames.key_from_name(area_name)
        filename = self.full_filepath(AreaNames.solar_pv_filename(area))

        SolarPVLoader.new(filename, solar_data)
        puts "Loaded #{solar_data.length} days of solar pv data"
      end
      @@solar_pv_data[area_name] = solar_data
    end
    @@solar_pv_data[area_name]
  end

  def self.uk_grid_carbon_intensity
    if @@uk_grid_carbon_intensity_data.nil?
      filename = INPUT_DATA_DIR + 'uk_carbon_intensity.csv'
      @@uk_grid_carbon_intensity_data = GridCarbonIntensity.new
      GridCarbonLoader.new(filename, @@uk_grid_carbon_intensity_data)
      puts "Loaded #{@@uk_grid_carbon_intensity_data.length} days of uk grid carbon intensity data"
    end
    @@uk_grid_carbon_intensity_data
  end

  def self.check_area_name(area)
    unless AreaNames.check_valid_area(area)
      raise EnergySparksUnexpectedSchoolDataConfiguration.new('Unexpected area configuration ' + area)
    end
  end
end

class AreaNames
  def self.key_from_name(name)
    AREA_NAMES.each do |key, area_data|
      return key if area_data[:name] == name
    end
    nil
  end

  def self.check_valid_area(area)
    AREA_NAMES.each_value do |area_data|
      return true if area_data[:name] == name
    end
  end

  def self.temperature_filename(key)
    AREA_NAMES[key][:temperature_filename]
  end

  def self.solar_irradiance_filename(key)
    AREA_NAMES[key][:solar_ir_filename]
  end

  def self.solar_pv_filename(key)
    AREA_NAMES[key][:solar_pv_filename]
  end

  def self.holiday_schedule_filename(key)
    AREA_NAMES[key][:holiday_calendar]
  end

  private

  AREA_NAMES = { # mapping from areas to csv data files for analytics non-db code
    bath: {
      name:                 'Bath',
      temperature_filename: 'Bath temperaturedata.csv',
      solar_ir_filename:    'Bath solardata.csv',
      solar_pv_filename:    'pv data Bath.csv',
      holiday_calendar:     'Holidays.csv'
    },
    frome: {
      name:                 'Frome',
      temperature_filename: 'Frome temperaturedata.csv',
      solar_ir_filename:    'Frome solardata.csv',
      solar_pv_filename:    'pv data Frome.csv',
      holiday_calendar:     'Holidays.csv'
    },
    bristol: {
      name:                 'Bristol',
      temperature_filename: 'Bristol temperaturedata.csv',
      solar_ir_filename:    'Bristol solardata.csv',
      solar_pv_filename:    'pv data Bristol.csv',
      holiday_calendar:     'Holidays.csv'
    },
    sheffield: {
      name:                 'Sheffield',
      temperature_filename: 'Sheffield temperaturedata.csv',
      solar_ir_filename:    'Sheffield solardata.csv',
      solar_pv_filename:    'pv data Sheffield.csv',
      holiday_calendar:     'Holidays.csv'
    }
  }.freeze
end
