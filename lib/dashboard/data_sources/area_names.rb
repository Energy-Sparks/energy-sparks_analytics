class AreaNames
  def self.key_from_name(name)
    AREA_NAMES.each do |key, area_data|
      return key if name.downcase.include?(key.to_s)
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

  def self.yahoo_location_name(key)
    AREA_NAMES[key][:yahoo_weather_forecast_id]
  end

  def self.met_office_weather_station_id(key)
    AREA_NAMES[key][:met_office_forecast_id]
  end

  private

  AREA_NAMES = { # mapping from areas to csv data files for analytics non-db code
    bath: {
      name:                       'Bath',
      temperature_filename:       'Bath temperaturedata.csv',
      solar_ir_filename:          'Bath solardata.csv',
      solar_pv_filename:          'pv data Bath.csv',
      holiday_calendar:           'Holidays.csv',
      yahoo_weather_forecast_id:  'bath, uk',
      met_office_forecast_id:     310026
    },
    frome: {
      name:                       'Frome',
      temperature_filename:       'Frome temperaturedata.csv',
      solar_ir_filename:          'Frome solardata.csv',
      solar_pv_filename:          'pv data Frome.csv',
      holiday_calendar:           'Holidays.csv',
      yahoo_weather_forecast_id:  'frome, uk', # untested 16Jan2019 post withdrawal of free API
      met_office_forecast_id:     351523
    },
    bristol: {
      name:                       'Bristol',
      temperature_filename:       'Bristol temperaturedata.csv',
      solar_ir_filename:          'Bristol solardata.csv',
      solar_pv_filename:          'pv data Bristol.csv',
      holiday_calendar:           'Holidays.csv',
      yahoo_weather_forecast_id:  'bristol, uk', # untested 16Jan2019 post withdrawal of free API
      met_office_forecast_id:     310004
    },
    sheffield: {
      name:                       'Sheffield',
      temperature_filename:       'Sheffield temperaturedata.csv',
      solar_ir_filename:          'Sheffield solardata.csv',
      solar_pv_filename:          'pv data Sheffield.csv',
      holiday_calendar:           'Holidays.csv',
      yahoo_weather_forecast_id:  'sheffield, uk', # untested 16Jan2019 post withdrawal of free API
      met_office_forecast_id:     353467
    }
  }.freeze
end
