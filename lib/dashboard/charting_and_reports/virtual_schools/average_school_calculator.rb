class AverageSchoolCalculator
  def initialize(school)
    @school = school
  end

  def benchmark_amr_data(type: :benchmark)
    calculate_school_amr_data(type: type)
  end

  def normalised_amr_data(type:, fuel_type:)
    calculate_school_amr_data(type: type, meter: @school.aggregate_meter(fuel_type), pupils: 1)
  end

  private

  def calculate_school_amr_data(type: :benchmark, meter: @school.aggregated_electricity_meters, pupils: @school.number_of_pupils)
    school_types = averaged_school_type_map(@school.school_type)
    interpolators = school_types.map do |school_type|
      # interpolators take ~3 ms to setup, so fast enough
      raw_data = AverageSchoolData.new.raw_data[:electricity][type][school_type.to_sym]
      create_14_months_of_interpolations(raw_data)
    end

    amr_data = meter.amr_data
    average_amr_data = AMRData.new(type)

    # calculation approx ~20 ms per year
    now = DateTime.now

    (amr_data.start_date..amr_data.end_date).each do |date|
      daytype = @school.holidays.day_type(date)
      avg_kwh_x48_by_school_type = interpolators.map do |interpolator|
        days_readings_x48(date.yday, interpolator[daytype])
      end
      kWh_per_pupil_x48 = AMRData.fast_average_multiple_x48(avg_kwh_x48_by_school_type)
      kWh_x48 = AMRData.fast_multiply_x48_x_scalar(kWh_per_pupil_x48, pupils) 
      average_amr_data.add(date, OneDayAMRReading.new(meter.mpxn, date, 'CAVG', nil, now, kWh_x48))
    end

    average_amr_data
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
    }

    school_map[school_type.to_sym]
  end

  def days_readings_x48(day_of_year, interpolators_x48)
    interpolators_x48.map do |interpolator|
      interpolator.at(day_of_year)
    end
  end

  def create_14_months_of_interpolations(average_meter_data)
    %i[schoolday weekend holiday].map do |daytype|
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
