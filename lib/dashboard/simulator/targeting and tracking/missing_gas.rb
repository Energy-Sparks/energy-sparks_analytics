class MissingGasEstimation < GasEstimationBase
  def complete_year_amr_data
    calc_class = case methodology
    when :model
    when :degree_days
      DegreeDayGasEstimation
    end

    calculator = calc_class.new(@meter, @annual_kwh)
    calculator.complete_year_amr_data
  end

  def methodology
    heating_model
    :model
  rescue EnergySparksNotEnoughDataException => e
    :degree_days
  end

  private

  def heating_model
    @heating_model ||= calculate_heating_model
  end

  def calculate_heating_model
    whole_meter_period = SchoolDatePeriod.year_to_date(:available, 'target model', @amr_data.start_date, @amr_data.end_date)
    @meter.heating_model(whole_meter_period)
  end
end
