#======================== Poor thermostatic control ==============
require_relative 'alert_gas_model_base.rb'

class AlertThermostaticControl < AlertGasModelBase
  attr_reader :a, :b, :r2, :base_temp
  MIN_R2 = 0.8

  def initialize(school)
    super(school)
  end

  def analyse(asof_date)
    calculate_model(asof_date)

    report = AlertReport.new(:thermostaticcontrol)
    report.add_book_mark_to_base_url('ThermostaticControl')
    report.term = :longterm

    @a = @heating_model.models[:heating_occupied_all_days].a
    @b = @heating_model.models[:heating_occupied_all_days].b
    @r2 = @heating_model.models[:heating_occupied_all_days].r2
    @base_temp = @heating_model.models[:heating_occupied_all_days].base_temperature

    if @r2 < MIN_R2
      report.summary = 'Thermostatic control of the school is poor'
      text = 'The thermostatic control of the heating at your school appears poor '
      text += sprintf('at an R2 of %.2f, ', @r2)
      text += sprintf('the school should aim to improve this to above %.2f', MIN_R2)
      report.rating = @r2 * 10.0
      report.status = :poor
    else
      report.summary = 'Thermostatic control at your school is good'
      text = 'The thermostatic control of the heating is good  '
      text += sprintf('at an R2 of %.2f', @r2)
      report.rating = 10.0
      report.status = :good
    end

    description1 = AlertDescriptionDetail.new(:text, text)
    report.add_detail(description1)
    add_report(report)
  end
end