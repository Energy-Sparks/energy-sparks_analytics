#======================== Poor thermostatic control ==============
require_relative 'alert_gas_model_base.rb'

class AlertThermostaticControl < AlertGasModelBase
  MIN_R2 = 0.8

  def initialize(school)
    super(school, :thermostaticcontrol)
  end

  def analyse_private(asof_date)
    calculate_model(asof_date)

    @analysis_report.add_book_mark_to_base_url('ThermostaticControl')
    @analysis_report.term = :longterm
    @analysis_report.summary = 'Thermostatic control of the school is ' + r2_rating_adjective
    text = 'The thermostatic control of the heating at your school appears ' + r2_rating_adjective
    text += sprintf('at an R2 of %.2f, ', r2)
    @analysis_report.rating = r2_rating_out_of_10
    @analysis_report.status = r2 < 0.5 ? :poor : :good
    description1 = AlertDescriptionDetail.new(:text, text)
    @analysis_report.add_detail(description1)
  end
end