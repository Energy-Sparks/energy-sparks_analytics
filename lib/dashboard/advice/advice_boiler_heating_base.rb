require_relative './advice_gas_base.rb'

class AdviceBoilerHeatingBase < AdviceGasBase
  include Logging

  def relevance
    super == :relevant &&  !non_heating_only? ? :relevant : :never_relevant
  end
  
  private

  def meter
    @school.aggregated_heat_meters
  end

  def heating_model(model_type: :best)
    @heating_model ||= calculate_heating_model(model_type)
  end

  def valid_model?
    heating_model
    true
  rescue EnergySparksNotEnoughDataException => e
    logger.info "Not running #{self.class.name} because model hasnt fitted"
    logger.info e.message
    false
  end

  def calculate_heating_model(model_type: :best)
    start_date = [meter.amr_data.end_date - 364, meter.amr_data.start_date].max
    last_year = SchoolDatePeriod.new(:analysis, 'validate amr', start_date, meter.amr_data.end_date)
    meter.heating_model(last_year, model_type)
  end
end
