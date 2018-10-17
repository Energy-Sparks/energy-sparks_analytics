class HeatingRegressionModelFitter

  attr_reader :meter_collection
  def initialize(meter_collection)
    @meter_collection = meter_collection
  end

  def run_temperature_balance_point_fit_on_simple_model_for_all_meters
    @meter_collection.heat_meters.each do |meter|
      run_temperature_balance_point_fit_on_simple_model(meter)
    end
  end

  def run_temperature_balance_point_fit_on_simple_model(meter)
    heat_amr = meter.amr_data
    start_date = heat_amr_data.start_date
    end_date = heat_amr_data.end_date
    period = SchoolDatePeriod.new(:fitting, 'Meter Period', start_date, end_date)

    puts "-" * 90
    puts "calculating simple model"
    simple_model = AnalyseHeatingAndHotWater::BasicRegressionHeatingModel.new(heat_amr_data, school.holidays, school.temperatures)
 
    for temperature in (8..30).step(0.5)
      simple_model.base_degreedays_temperature = temperature
      simple_model.calculate_regression_model(period)
      sd, mean = simple_model.cusum_standard_deviation_average
      if sd.nan? || mean.nan?
        puts "simple: t = #{temperature} NaN"
      else
        puts "simple: t = #{temperature} sd = #{sd.round(0)} mean = #{mean.round(0)}"
      end
    end
  end
end