class MissingGasEstimation < GasEstimationBase
  def complete_year_amr_data
    calc_class = case methodology
    when :model
      ModelGasEstimation
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
end
