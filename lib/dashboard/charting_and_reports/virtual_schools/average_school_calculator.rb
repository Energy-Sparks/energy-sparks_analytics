class AverageSchoolCalculator
  class UnexpectedSchoolTypeException < StandardError;  end

  def initialize(school)
    @school = school
  end

  def benchmark_amr_data(meter:, benchmark_type: :benchmark)
    calculate_school_amr_data(meter: meter, benchmark_type: benchmark_type)
  end

  def normalised_amr_data(benchmark_type:, fuel_type:, degreeday_adjustment: false)
    calculate_school_amr_data(meter: @school.aggregate_meter(fuel_type), benchmark_type: benchmark_type, pupils: 1, floor_area: 1, degreeday_adjustment: degreeday_adjustment)
  end

  def self.remap_low_sample_holiday(holiday_type)
    holiday_type == :mayday ? :easter : holiday_type
  end

  def self.remap_low_sample_holiday2(date)
    # e.g. Llanmart had single day 19-Sep-2022 holiday
    date.month == 9 ? :summer : nil
  end

  private

  def calculate_school_amr_data(meter:, benchmark_type: :benchmark, pupils: @school.number_of_pupils, floor_area: @school.floor_area, degreeday_adjustment: true)
    amr_data = meter.amr_data
    average_amr_data = AMRData.new(benchmark_type)

    interpolators = calculate_interpolators(benchmark_type, meter.fuel_type)

    # calculation approx ~20 ms per year
    now = DateTime.now

    scale_by =  if meter.fuel_type == :electricity
                  pupils
                elsif degreeday_adjustment
                  degree_days_to_average_factor_reversed(meter.meter_collection, amr_data.start_date, amr_data.end_date, floor_area)
                else
                  floor_area
                end

    (amr_data.start_date..amr_data.end_date).each do |date|
      avg_kwh_x48_by_school_type = school_type_profiles_to_average_x48(date, benchmark_type, interpolators, meter.fuel_type)

      kWh_per_pupil_x48 = AMRData.fast_average_multiple_x48(avg_kwh_x48_by_school_type)

      kWh_x48 = AMRData.fast_multiply_x48_x_scalar(kWh_per_pupil_x48, scale_by)

      average_amr_data.add(date, OneDayAMRReading.new(meter.mpxn, date, 'CAVG', nil, now, kWh_x48))
    end

    average_amr_data
  end

  def degree_days_to_average_factor_reversed(school, start_date, end_date, floor_area)
    end_date   = [end_date, school.temperatures.end_date].min
    start_date = [end_date - 365, school.temperatures.start_date].max

    return floor_area if end_date - start_date < 360 # shouldn't happen as temperatures should be backdated a year

    avg_degree_days = BenchmarkMetrics::ANNUAL_AVERAGE_DEGREE_DAYS

    school_degree_days = school.temperatures.degree_days_in_date_range(start_date, end_date)

    # very crude for as really need to scale monthly degree days
    # versus precalculated national average for each month
    # school.aggregated_heat_meters.heating_model.heating_on?(date)

    # if a school is colder than average i.e. > school_degree_days increase its consumption from average

    floor_area * school_degree_days / avg_degree_days
  end

  def school_type_profiles_to_average_x48(date, benchmark_type, interpolators, fuel_type)
    daytype = @school.holidays.day_type(date)

    if daytype == :holiday
      holiday_type = Holidays.holiday_type(date)
      holiday_type = self.class.remap_low_sample_holiday(holiday_type)
      holiday_type = self.class.remap_low_sample_holiday2(date) if holiday_type.nil?

      averaged_school_type_map(@school.school_type).map do |school_type|
        Schools::AverageSchoolData.raw_data[fuel_type][benchmark_type][school_type.to_sym][:holiday][holiday_type]
      end
    else
      avg_kwh_x48_by_school_type = interpolators.map do |interpolator|
        days_readings_x48(date.yday, interpolator[daytype])
      end
    end
  end

  def calculate_interpolators(benchmark_type, fuel_type)
    school_types = averaged_school_type_map(@school.school_type)
    interpolators = school_types.map do |school_type|
      # interpolators take ~3 ms to setup, so fast enough
      raw_data = Schools::AverageSchoolData.raw_data[fuel_type][benchmark_type][school_type.to_sym]
      create_14_months_of_interpolations(raw_data)
    end
  end

  # there is only enough samples at the moment 25Oct2021 to
  # use the data for :primary and :secondary, so average the
  # other school types apart from special - which is normalised
  # penalised, so for moment use :special despite the lack of samples
  def averaged_school_type_map(school_type)
    school_map = {
      primary:                      [ :primary ],
      special:                      [ :special ],
      secondary:                    [ :secondary ],
      mixed_primary_and_secondary:  [ :primary, :secondary ],
      middle:                       [ :primary, :secondary ],
      infant:                       [ :primary ],
      junior:                       [ :primary ],
    }

    raise UnexpectedSchoolTypeException, "Unknown school type #{school_type}" unless school_map.key?(school_type.to_sym)

    school_map[school_type.to_sym]
  end

  def days_readings_x48(day_of_year, interpolators_x48)
    interpolators_x48.map do |interpolator|
      interpolator.at(day_of_year)
    end
  end

  def create_14_months_of_interpolations(average_meter_data)
    %i[schoolday weekend].map do |daytype|
      extended_months_data = configure_14_months(average_meter_data[daytype])
      [
        daytype,
        setup_intraday_interpolators_x48_half_hours_x14_months(extended_months_data)
      ]
    end.to_h
  end

  def configure_14_months(months_data)
    # for interpolation purposes add a month on and start and end of a year
    # so the data wraps around for interpolation, rather than the interpolation
    # being truncated
    months_data[0]  = months_data[12]
    months_data[13] = months_data[0]

    # overwrite Scottish specific school data
    # - Scottish schools currently have very high usage and
    #   distort averages at specific times of year e.g.
    #   school days in August - as no English/Welsh schools
    #   are represented
    months_data[8] = months_data[7]

    months_data.sort.to_h
  end

  # returns 48 (half hour) interpolators - each covering 14 months
  def setup_intraday_interpolators_x48_half_hours_x14_months(extended_months_data)
    days_since_start_of_year = [-15, 15, 45, 75, 105, 135, 165, 195, 225, 255, 285, 315, 345, 380]

    (0..47).map do |half_hour|
      kwh_per_hh_per_pupil = extended_months_data.keys.map do |month|
        extended_months_data[month][half_hour]
      end
      Interpolate::Points.new(days_since_start_of_year.zip(kwh_per_hh_per_pupil).to_h)
    end
  end
end
