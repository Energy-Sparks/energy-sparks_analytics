require 'require_all'
require_relative '../../lib/dashboard.rb'
require_rel '../../test_support'

module Logging
  @logger = Logger.new('log/sheffield solar pv ' + Time.now.strftime('%H %M') + '.log')
  logger.level = :debug
end

class PVPanelAzimuthAngleAdjustment
  SHEFFIELD_PV_ANGLE  =  30
  SHEFIELD_PV_AZIMUTH = 180
  UK_TIMEZONE_HOUR_OFFSET = 1
  MAX_FACTOR = 10.0
  def initialize(latitude, longitude, panel_angle, panel_azimuth)
    @latitude  = latitude
    @longitude = longitude

    @panel_angle   = panel_angle
    @panel_azimuth = panel_azimuth
  end

  def cached_approx_pv_yield_ratio(datetime)
    @cached_approx_pv_yield_ratio ||= {}
    key = DateTime.new(2023, datetime.month, 15, datetime.hour, datetime.minute)

    @cached_approx_pv_yield_ratio[key] ||= pv_yield_ratio(key)
  end

  def pv_yield_ratio(datetime)
    sun_orientation = SunAngleOrientation.angle_orientation(datetime, @latitude, @longitude, UK_TIMEZONE_HOUR_OFFSET)

    return 0.0 if sun_orientation[:solar_elevation_degrees] <= 0.0 # below horizon

    panel_factor = calculate_panel_orientation_factor(
                      sun_orientation[:solar_elevation_degrees],
                      sun_orientation[:solar_azimuth_degrees],
                      @panel_angle,
                      @panel_azimuth
                    )

    return 0.0 if panel_factor <= 0.0

    sheffield_panel_factor = calculate_panel_orientation_factor(
      sun_orientation[:solar_elevation_degrees],
      sun_orientation[:solar_azimuth_degrees],
      SHEFFIELD_PV_ANGLE,
      SHEFIELD_PV_AZIMUTH
    )

    if datetime == DateTime.new(2022, 4, 30, 17, 0)
      puts "Factors for #{datetime}"
      ap sun_orientation
      puts "Panel factor #{panel_factor}"
      puts "Sheffield #{sheffield_panel_factor}"
      puts "Ratio #{[panel_factor / sheffield_panel_factor, MAX_FACTOR].min}"
    end

    return 0.0 if sheffield_panel_factor <= 0.0

    [panel_factor / sheffield_panel_factor, MAX_FACTOR].min
  end

  private

    # https://www.pveducation.org/pvcdrom/properties-of-sunlight/arbitrary-orientation-and-tilt
  def calculate_panel_orientation_factor(sun_elevation, sun_azimuth, panel_angle, panel_azimuth)
    a = cos(sun_elevation) * sin(panel_angle) * cos(panel_azimuth - sun_azimuth)
    b = sin(sun_elevation) * cos(panel_angle)
    a + b
  end

  def sin(deg)
    Math.sin(radians(deg))
  end
  
    
  def cos(deg)
    Math.cos(radians(deg))
  end

  def radians(d)
    d.to_f / 360.0 * 2.0 * Math::PI
  end
end

def calculate_years_factors(school, meter, panel_azimuth, panel_angle = 30)
  puts "Calculating factors for #{panel_azimuth} #{panel_angle}"
  pv_factor = PVPanelAzimuthAngleAdjustment.new(school.latitude, school.longitude, panel_angle, panel_azimuth)

  end_date = meter.amr_data.end_date
  start_date = [end_date - 365, meter.amr_data.start_date].max

  dates = start_date..end_date
  # dates = [end_date - 1, end_date]

  data = {}

  dates.each do |date|
    data[date] = []
    (0..23).each do |hour|
      [0, 30].each do |minute|
        dt = DateTime.new(date.year, date.month, date.day, hour, minute)
        f = pv_factor.pv_yield_ratio(dt)
        data[date].push(f)
      end
    end
  end
  data
end

def save_csv(filename, results)
  puts "Saving to #{filename}"
  CSV.open(filename, 'w' ) do |csv|
    results.each do |date, days_data|
      csv << [date, days_data.sum, days_data].flatten
    end
  end
end

def test_dir(school_name)
  File.join(TestDirectory.instance.results_directory('Results'), school_name + '.xlsx')
end

def save_to_excel(filename, data)
  excel = ExcelCharts.new(filename)
  data.each do |worksheet_name, charts|
    excel.add_charts(worksheet_name, charts.compact)
  end
  excel.close
end

def run_chart(school, chart_name, override)
  chart_manager = ChartManager.new(school)
  chart_manager.run_chart_group(chart_name, override, true, provide_advice: false)
end

def solar_pv_attributes(meter)
  meter.meter_attributes[:solar_pv][0]
end

def calculate_solar_azimuth_half_hour_offset(school, attributes)
  return attributes[:azimuth_hours_offset] unless attributes[:azimuth_hours_offset].nil?

  azimuth_degrees = attributes[:azimuth_override] || attributes[:azimuth]
  
  return 0 if azimuth_degrees.nil?

  degrees_per_hour = SunAngleOrientation.average_azimuth_change_degrees_per_hour(school.latitude, school.longitude)
  degrees_offset = azimuth_degrees - 180
  hours = degrees_offset / degrees_per_hour
  (hours * 2.0).round(0)
end

def adjust(x48)
  x48.each_with_index do |v, i|
    x48[i] = v * 1000.0
  end
end

def updated_solar_pv_calculation(school, sub_meters, date, baseload_kw, pv_hh_offset)
  return if school.holidays.occupied?(date)
  pv_factor = PVPanelAzimuthAngleAdjustment.new(school.latitude, school.longitude, 30, 124)

  (0..47).each do |hh_i|
    corrected_pv_hhi = [[hh_i - pv_hh_offset, 0].max, 47].min
    generation_kwh            = sub_meters[:generation].amr_data.kwh(date, corrected_pv_hhi)

    fudge_hhi_offset = 0
    dt = DateTimeHelper.datetime(date, hh_i)
    f = pv_factor.pv_yield_ratio(dt)
    hhi_offset = [[hh_i + fudge_hhi_offset, 0].max, 47].min
    generation_kwh            = sub_meters[:generation].amr_data.kwh(date, hhi_offset) * f

    mains_kwh                 = sub_meters[:mains_consume].amr_data.kwh(date, hh_i)
    unoccupied_appliance_kwh  = [mains_kwh, baseload_kw / 2.0].max

    exporting             = generation_kwh > unoccupied_appliance_kwh
    export_kwh            = exporting ? [unoccupied_appliance_kwh - generation_kwh, 0.0].min : 0.0
    solar_pv_on           = generation_kwh > 0.0
    self_consumption_kwh  = solar_pv_on ? [unoccupied_appliance_kwh - mains_kwh, 0.0].max : 0.0

    sub_meters[:export      ].amr_data.set_kwh(date, hh_i, export_kwh)
    sub_meters[:self_consume].amr_data.set_kwh(date, hh_i, self_consumption_kwh)
  end
end

def baseload_kw(meter, yesterday_date)
  yesterday_date = meter.amr_data.start_date if yesterday_date < meter.amr_data.start_date
  meter.amr_data.overnight_baseload_kw(yesterday_date)
end

def recalculate_solar_pv(meter, attributes, pv_hhi_offset)
  start_date = attributes[:start_date]
  end_date = meter.amr_data.end_date
  (start_date..end_date).each do |date|
    baseload_kw = baseload_kw(meter, date - 1)
    updated_solar_pv_calculation(meter.meter_collection, meter.sub_meters, date, baseload_kw, pv_hhi_offset)
  end
end

def dates(date)
  return [date]                    if date.is_a?(Date)
  return date.map { |d| dates(d) } if date.is_a?(Array)
  return date.to_a                 if date.is_a?(Range) 
end

def annual_kwh(chart_results)
  summary = {}
  data = chart_results[:x_data]
  summary[:mains] = data['Electricity consumed from mains'].sum.round(0)
  summary[:exp]   = data['Exported solar electricity (not consumed onsite)'].sum.round(0)
  summary[:self]  = data['Electricity consumed from solar pv'].sum.round(0)
  summary
end

days = [
  Date.new(2022,  4,  3),
  Date.new(2022,  6, 25),
  Date.new(2022,  8,  6),
  Date.new(2022, 10, 28),
  Date.new(2022, 12, 26),
  Date.new(2023,  4,  12), # Hastings looks strange
]

config = {
  'Sutton Park Primary School' => { azimuth_hours_offset: -6, azimuth: 124, date: days },
  'Hastings High School'       => { azimuth_hours_offset:  0, azimuth: 180, date: days }
}

school_name_pattern_match = ['*']
source_db = :unvalidated_meter_data
chart = :management_dashboard_group_by_month_solar_pv

school_names = SchoolFactory.instance.school_file_list(source_db, school_name_pattern_match)

school_names.each do |school_name|
  school = SchoolFactory.instance.load_school(source_db, school_name, cache: true)
  raise 'Too many meters' unless school.electricity_meters.length == 1

  meter = school.electricity_meters[0]

  factors = calculate_years_factors(school, meter, config[school.name][:azimuth])
  save_csv('../factors.csv', factors)

  attributes = solar_pv_attributes(meter)

  puts "#{school.name} #{config[school.name]}"
  ap attributes

  ds = dates(config[school.name][:date]).flatten
  overrides = ds.map do |date|
      {
        timescale: { daterange: date..date },
        x_axis:    :datetime,
      }
  end

  c2_before = []
  c2_after  = []

  c1_before = run_chart(school, :management_dashboard_group_by_month_solar_pv, nil)
  overrides.each do |override|
    c2_before.push(run_chart(school, :management_dashboard_group_by_month_solar_pv, override))
  end
 
  half_hour_offset = calculate_solar_azimuth_half_hour_offset(school, config[school.name])
  puts "Offset = #{half_hour_offset}"

  recalculate_solar_pv(meter, attributes, half_hour_offset)

  c1_after = run_chart(school, :management_dashboard_group_by_month_solar_pv, nil)
  overrides.each do |override|
    c2_after.push(run_chart(school, :management_dashboard_group_by_month_solar_pv, override))
  end

  puts "Before: #{annual_kwh(c1_before)}"
  puts "After:  #{annual_kwh(c1_after)}"

  data = { 'test' => [c1_before, c1_after, c2_before, c1_after, c2_after].flatten }

  save_to_excel(test_dir(school.name), data)
end
