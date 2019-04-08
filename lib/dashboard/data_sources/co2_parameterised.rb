# provides UK electricity grid carbon intensity factors by date to date/time
# the rails environment currently hasn't implemented the uk grid carbon feed
# so make the data up from parameterised data - which is not ideal if the
# data is to be scrutinised at the sub-week, datetime level, and also post
# 24Mar2019 as the detailed data starts getting out of date
# uses this parameterised data to backfile pre 2017 feed data, and post live future projections
# called from schedule data manager - only one instance for the application
class CO2Parameterised
  @@date_to_carbon_intensity_map_kg_per_kwh = nil

  # the half_hourly feed only start in 2017, so back populate with historic parameterised
  # data, and forward populate the projections - dangerous in that it might hide the
  # feed stopping working?
  def self.fill_in_missing_uk_grid_carbon_intensity_data_with_parameterised(grid_carbon)
    before_count = grid_carbon.length
    start_date = HARDCODEDMAINSGRIDINTENSITY.keys[0].first
    end_date = HARDCODEDMAINSGRIDINTENSITY.keys[HARDCODEDMAINSGRIDINTENSITY.length - 1].last
    (start_date..end_date).each do |date|
      if grid_carbon.date_missing?(date)
        carbon_intensity_kg_per_kwh = carbon_intensity_date_kg_per_kwh(date)
        grid_carbon.add(date, Array.new(48, carbon_intensity_kg_per_kwh))
      end
    end
    puts "Added an additional #{grid_carbon.length - before_count} days of parameterised data to existing #{before_count} of feed data"
    grid_carbon
  end

  def self.create_uk_grid_carbon_intensity_from_parameterised_data
    feed = download_this_years_data_from_internet
    grid_carbon = GridCarbonIntensity.new
    start_date = HARDCODEDMAINSGRIDINTENSITY.keys[0].first
    end_date = HARDCODEDMAINSGRIDINTENSITY.keys[HARDCODEDMAINSGRIDINTENSITY.length - 1].last
    (start_date..end_date).each do |date|
      if feed.day_readings.key?(date) && !(feed.day_readings[date].count{ |co2_hh| co2_hh.nil?  } >= 1)
        grid_carbon.add(date, feed.day_readings[date])
      else
        carbon_intensity_kg_per_kwh = carbon_intensity_date_kg_per_kwh(date)
        grid_carbon.add(date, Array.new(48, carbon_intensity_kg_per_kwh))
      end
    end
    puts "Created #{grid_carbon.length} days of uk grid_carbon_intensity_data"
    grid_carbon
  end

  # in the abscence of a front end batch job to do this, download
  # year's data so recent charts have intraday detail
  # pre 2019 intraday data will need to wait for a batch job
  def self.download_this_years_data_from_internet
    feed = UKGridCarbonIntensityFeed.new
    start_date = Date.new(2019, 1, 1)
  end_date = Date.today - 1
    feed.download(start_date, end_date)
    feed
  end

  def self.carbon_intensity_date_kg_per_kwh(date)
    # this call is O(N^2) and takes 1 minute to run: HARDCODEDMAINSGRIDINTENSITY.select {|date_range| date_range === date }.values.first / 1_000.0
    # so run through the date_range hash creating a faster access date hash
    if @@date_to_carbon_intensity_map_kg_per_kwh.nil?
      @@date_to_carbon_intensity_map_kg_per_kwh = {}
      HARDCODEDMAINSGRIDINTENSITY.each do |date_range, carbon_intensity_g_per_kwh|
        date_range.each do |date_in_range|
          @@date_to_carbon_intensity_map_kg_per_kwh[date_in_range] = carbon_intensity_g_per_kwh / 1_000.0
        end
      end
    end
    @@date_to_carbon_intensity_map_kg_per_kwh[date]
  end

  private # not sure private works for constants?????

  HARDCODEDMAINSGRIDINTENSITY = {
    # https://www.mygridgb.co.uk/historicaldata/ - however (PH, 24Mar2019) thinks these are perhaps 30g/kWh too low?
    Date.new(2007,  1, 1)..Date.new(2007,  12, 31)  => 510.0,
    Date.new(2008,  1, 1)..Date.new(2008,  12, 31)  => 502.0,
    Date.new(2009,  1, 1)..Date.new(2009,  12, 31)  => 472.0,
    Date.new(2010,  1, 1)..Date.new(2010,  12, 31)  => 481.0,
    Date.new(2011,  1, 1)..Date.new(2011,  12, 31)  => 455.0,
    Date.new(2012,  1, 1)..Date.new(2012,  12, 31)  => 467.0,
    Date.new(2013,  1, 1)..Date.new(2013,  12, 31)  => 434.0,
    Date.new(2014,  1, 1)..Date.new(2014,  12, 31)  => 390.0,
    Date.new(2015,  1, 1)..Date.new(2015,  12, 31)  => 336.0,
    Date.new(2016,  1, 1)..Date.new(2016,  12, 31)  => 330.0,
    Date.new(2017,  1, 1)..Date.new(2017,   9, 18)  => 279.0,
    # from Energy Sparks grid carbon download - extracted from download csv file and grouped to week level
    Date.new(2017,  9, 19)..Date.new(2017,  9, 25)  => 268.9,
    Date.new(2017,  9, 19)..Date.new(2017,  9, 25)  => 268.9,
    Date.new(2017,  9, 19)..Date.new(2017,  9, 25)  => 268.9,
    Date.new(2017,  9, 26)..Date.new(2017,  10, 2)  => 227.5,
    Date.new(2017,  10, 3)..Date.new(2017,  10, 9)  => 219.3,
    Date.new(2017,  10, 10)..Date.new(2017,  10, 16)  => 217.1,
    Date.new(2017,  10, 17)..Date.new(2017,  10, 23)  => 265.9,
    Date.new(2017,  10, 24)..Date.new(2017,  10, 30)  => 248.3,
    Date.new(2017,  10, 31)..Date.new(2017,  11, 6)  => 282,
    Date.new(2017,  11, 7)..Date.new(2017,  11, 13)  => 300.8,
    Date.new(2017,  11, 14)..Date.new(2017,  11, 20)  => 347.7,
    Date.new(2017,  11, 21)..Date.new(2017,  11, 27)  => 308,
    Date.new(2017,  11, 28)..Date.new(2017,  12, 4)  => 380.8,
    Date.new(2017,  12, 5)..Date.new(2017,  12, 11)  => 350.7,
    Date.new(2017,  12, 12)..Date.new(2017,  12, 18)  => 361.9,
    Date.new(2017,  12, 19)..Date.new(2017,  12, 25)  => 285.4,
    Date.new(2017,  12, 26)..Date.new(2018,  1, 1)  => 218.3,
    Date.new(2018,  1, 2)..Date.new(2018,  1, 8)  => 268.9,
    Date.new(2018,  1, 9)..Date.new(2018,  1, 15)  => 296.4,
    Date.new(2018,  1, 16)..Date.new(2018,  1, 22)  => 243.2,
    Date.new(2018,  1, 23)..Date.new(2018,  1, 29)  => 219.6,
    Date.new(2018,  1, 30)..Date.new(2018,  2, 5)  => 262.8,
    Date.new(2018,  2, 6)..Date.new(2018,  2, 12)  => 264.6,
    Date.new(2018,  2, 13)..Date.new(2018,  2, 19)  => 268.8,
    Date.new(2018,  2, 20)..Date.new(2018,  2, 26)  => 327.6,
    Date.new(2018,  2, 27)..Date.new(2018,  3, 5)  => 381.1,
    Date.new(2018,  3, 6)..Date.new(2018,  3, 12)  => 332.7,
    Date.new(2018,  3, 13)..Date.new(2018,  3, 19)  => 310.5,
    Date.new(2018,  3, 20)..Date.new(2018,  3, 26)  => 311.8,
    Date.new(2018,  3, 27)..Date.new(2018,  4, 2)  => 258,
    Date.new(2018,  4, 3)..Date.new(2018,  4, 9)  => 238.3,
    Date.new(2018,  4, 10)..Date.new(2018,  4, 16)  => 258.2,
    Date.new(2018,  4, 17)..Date.new(2018,  4, 23)  => 188.4,
    Date.new(2018,  4, 24)..Date.new(2018,  4, 30)  => 223.7,
    Date.new(2018,  5, 1)..Date.new(2018,  5, 7)  => 206.9,
    Date.new(2018,  5, 8)..Date.new(2018,  5, 14)  => 208.9,
    Date.new(2018,  5, 15)..Date.new(2018,  5, 21)  => 223.7,
    Date.new(2018,  5, 22)..Date.new(2018,  5, 28)  => 211.1,
    Date.new(2018,  5, 29)..Date.new(2018,  6, 4)  => 253.3,
    Date.new(2018,  6, 5)..Date.new(2018,  6, 11)  => 254.6,
    Date.new(2018,  6, 12)..Date.new(2018,  6, 18)  => 205.2,
    Date.new(2018,  6, 19)..Date.new(2018,  6, 25)  => 233.7,
    Date.new(2018,  6, 26)..Date.new(2018,  7, 2)  => 242.1,
    Date.new(2018,  7, 3)..Date.new(2018,  7, 9)  => 267.2,
    Date.new(2018,  7, 10)..Date.new(2018,  7, 16)  => 268.6,
    Date.new(2018,  7, 17)..Date.new(2018,  7, 23)  => 270.7,
    Date.new(2018,  7, 24)..Date.new(2018,  7, 30)  => 204.6,
    Date.new(2018,  7, 31)..Date.new(2018,  8, 6)  => 222.9,
    Date.new(2018,  8, 7)..Date.new(2018,  8, 13)  => 227.1,
    Date.new(2018,  8, 14)..Date.new(2018,  8, 20)  => 200.8,
    Date.new(2018,  8, 21)..Date.new(2018,  8, 27)  => 193.2,
    Date.new(2018,  8, 28)..Date.new(2018,  9, 3)  => 254.4,
    Date.new(2018,  9, 4)..Date.new(2018,  9, 10)  => 237.3,
    Date.new(2018,  9, 11)..Date.new(2018,  9, 17)  => 214.9,
    Date.new(2018,  9, 18)..Date.new(2018,  9, 24)  => 201.1,
    Date.new(2018,  9, 25)..Date.new(2018,  10, 1)  => 231.2,
    Date.new(2018,  10, 2)..Date.new(2018,  10, 8)  => 230.9,
    Date.new(2018,  10, 9)..Date.new(2018,  10, 15)  => 210.6,
    Date.new(2018,  10, 16)..Date.new(2018,  10, 22)  => 261.5,
    Date.new(2018,  10, 23)..Date.new(2018,  10, 29)  => 209.9,
    Date.new(2018,  10, 30)..Date.new(2018,  11, 5)  => 273.9,
    Date.new(2018,  11, 6)..Date.new(2018,  11, 12)  => 208.3,
    Date.new(2018,  11, 13)..Date.new(2018,  11, 19)  => 271.4,
    Date.new(2018,  11, 20)..Date.new(2018,  11, 26)  => 341.1,
    Date.new(2018,  11, 27)..Date.new(2018,  12, 3)  => 233.3,
    Date.new(2018,  12, 4)..Date.new(2018,  12, 10)  => 232.4,
    Date.new(2018,  12, 11)..Date.new(2018,  12, 17)  => 253.7,
    Date.new(2018,  12, 18)..Date.new(2018,  12, 24)  => 256.1,
    Date.new(2018,  12, 25)..Date.new(2018,  12, 31)  => 232.4,
    Date.new(2019,  1, 1)..Date.new(2019,  1, 7)  => 294.8,
    Date.new(2019,  1, 8)..Date.new(2019,  1, 14)  => 247.1,
    Date.new(2019,  1, 15)..Date.new(2019,  1, 21)  => 287.3,
    Date.new(2019,  1, 22)..Date.new(2019,  1, 28)  => 273.5,
    Date.new(2019,  1, 29)..Date.new(2019,  2, 4)  => 286.7,
    Date.new(2019,  2, 5)..Date.new(2019,  2, 11)  => 214.5,
    Date.new(2019,  2, 12)..Date.new(2019,  2, 18)  => 185.9,
    Date.new(2019,  2, 19)..Date.new(2019,  2, 25)  => 204.5,
    Date.new(2019,  2, 26)..Date.new(2019,  3, 4)  => 229.1,
    Date.new(2019,  3, 5)..Date.new(2019,  3, 11)  => 178.4,
    Date.new(2019,  3, 12)..Date.new(2019,  3, 18)  => 174.4,
    Date.new(2019,  3, 19)..Date.new(2019,  3, 25)  => 231.9,
    Date.new(2019,  3, 20)..Date.new(2019,  12, 31)  => 210.0,
    # https://www.icax.co.uk/Grid_Carbon_Factors.html
    # https://assets.publishing.service.gov.uk/government/uploads/system/uploads/attachment_data/file/671187/Updated_energy_and_emissions_projections_2017.pdf Fig 5.2
    # made these up a little as some of the projections for this year are already wrong
    # probably a little higher than projected (PH, 24Mar2019):
    Date.new(2020,  1, 1)..Date.new(2020,  12, 31)  => 210.0,
    Date.new(2021,  1, 1)..Date.new(2021,  12, 31)  => 180.0,
    Date.new(2022,  1, 1)..Date.new(2022,  12, 31)  => 160.0,
    Date.new(2023,  1, 1)..Date.new(2023,  12, 31)  => 150.0,
    Date.new(2024,  1, 1)..Date.new(2025,  12, 31)  => 140.0,
  }.freeze
end
