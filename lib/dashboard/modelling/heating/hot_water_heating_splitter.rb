class HotWaterHeatingSplitter
  def initialize(school)
    @school = school
  end

  def split_heat_and_hot_water(start_date, end_date)
    average_hot_water_only_day_kwh_x48 = average_hot_water_day_x48(start_date, end_date)
    average_hot_water_only_day_kwh = average_hot_water_only_day_kwh_x48.sum

    heating_days  = AMRData.create_empty_dataset(:heating,    start_date, end_date)
    hotwater_days = AMRData.create_empty_dataset(:hot_water,  start_date, end_date)

    (start_date..end_date).each do |date|
      if @heating_model.model_type?(date) == :summer_occupied_all_days
        hotwater_days.add(date, @school.aggregated_heat_meters.amr_data.days_amr_data(date))
      elsif @heating_model.model_type?(date) != :none
        hw_day = OneDayAMRReading.new(0, date, 'HSIM', nil, DateTime.now, average_hot_water_only_day_kwh_x48)
        hotwater_days.add(date, hw_day)

        days_data_kwh_x48 = @school.aggregated_heat_meters.amr_data.days_kwh_x48(date)
        heating_days_data_kwh_x48 = remove_hot_water_from_heating_data(date, days_data_kwh_x48, average_hot_water_only_day_kwh_x48)
        heating_day = OneDayAMRReading.new(0, date, 'HSIM', nil, DateTime.now, heating_days_data_kwh_x48)
        heating_days.add(date, heating_day)
      end
    end

    total = @school.aggregated_heat_meters.amr_data.kwh_date_range(start_date, end_date)
    total_heating = heating_days.total
    total_hot_water = hotwater_days.total
    error = total - total_heating - total_hot_water # would expect small error dur to 'max' function in remove_hot_water_from_heating_data
    puts "Total heating #{total_heating} total hot water #{total_hot_water} error #{error}"
    {
      heating_only_amr:           heating_days,
      hot_water_only_amr:         hotwater_days,
      average_hot_water_day_kwh:  average_hot_water_only_day_kwh_x48.sum,
      error_kwh:                  error,
      error_percent:              error / total
    }
  end

  def aggregate_heating_hot_water_split(start_date, end_date)
    calc = split_heat_and_hot_water(start_date, end_date)
    heating_kwh   = calc[:heating_only_amr].total
    hotwater_kwh  = calc[:hot_water_only_amr].total
    total_kwh = heating_kwh + hotwater_kwh
    {
      heating_kwh:                heating_kwh,
      hotwater_kwh:               hotwater_kwh,
      total_kwh:                  total_kwh,
      heating_percent:            heating_kwh / total_kwh,
      hotwater_percent:           hotwater_kwh / total_kwh,
      average_hot_water_day_kwh:  calc[:average_hot_water_day_kwh],
      error_kwh:                  calc[:error_kwh],
      error_percent:              calc[:error_percent]
    }
  end

  private

  # TODO(PH, 18Jun2020) probably needs a rethink as result is noisy so sum of inputs != output
  def remove_hot_water_from_heating_data(date_for_debug, heating_and_hw_data_kwh_x48, hot_water_kwh_x48)
    return AMRData.one_day_zero_kwh_x48 if hot_water_kwh_x48.sum > heating_and_hw_data_kwh_x48.sum

    excess_hw_consumption_kwh = 0.0 # rollover any hot water consumption > total consumption to next half hour
    x = heating_and_hw_data_kwh_x48.each_with_index.map do |hh_kwh, half_hour_index|
      heating_consumption = hh_kwh - hot_water_kwh_x48[half_hour_index] - excess_hw_consumption_kwh
      if heating_consumption < 0.0
        excess_hw_consumption_kwh = -heating_consumption
        heating_consumption = 0.0
      else
        excess_hw_consumption_kwh = 0.0
      end
      heating_consumption
    end
    if false && date_for_debug == Date.new(2018,9,24)
      y = heating_and_hw_data_kwh_x48.each_with_index.map do |hh_kwh, hhi|
        [heating_and_hw_data_kwh_x48[hhi], hot_water_kwh_x48[hhi], x[hhi]]
      end
      puts "heat+hw #{heating_and_hw_data_kwh_x48.sum.round(0)}, avg hw #{hot_water_kwh_x48.sum.round(0)}, heat only #{x.sum.round(0)}"
      ap y
    end
    x
  end


  def average_hot_water_day_x48(start_date, end_date)
    @heating_model ||= calculate_model(start_date, end_date)

    hot_water_days = 0
    aggregated_hot_water_days = AMRData.one_day_zero_kwh_x48

    (start_date..end_date).each do |date|
      if @heating_model.model_type?(date) == :summer_occupied_all_days
        days_kwh_x48 = @school.aggregated_heat_meters.amr_data.days_kwh_x48(date)
        aggregated_hot_water_days = AMRData.fast_add_x48_x_x48(days_kwh_x48, aggregated_hot_water_days)
        hot_water_days += 1
      end
    end

    AMRData.fast_multiply_x48_x_scalar(aggregated_hot_water_days, 1.0 / hot_water_days)
  end

  def calculate_model(start_date, end_date)
    model_period = SchoolDatePeriod.new(:heat_balance_simulation, 'Current Year', start_date, end_date)
    @heating_model = @school.aggregated_heat_meters.heating_model(model_period)
  end
end