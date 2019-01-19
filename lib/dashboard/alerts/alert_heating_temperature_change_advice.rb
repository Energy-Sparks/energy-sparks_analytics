#======================== Heating Sensitivity Advice ==============
require_relative 'alert_gas_model_base.rb'

class AlertHeatingSensitivityAdvice < AlertGasModelBase
  attr_reader :kwh_per_1_C

  def initialize(school)
    super(school, :heatingsensitivity)
  end

  def analyse_private(asof_date)
    calculate_model(asof_date)

    start_date = [asof_date - 365, @school.aggregated_heat_meters.amr_data.start_date].max
    # @analysis_report.add_book_mark_to_base_url('ThermostaticControl')
    @analysis_report.term = :longterm

    months = ((asof_date - start_date) / 30.0).floor

    if months < 12
      @analysis_report.summary = 'Not enough (<1 year) historic gas data to provide advice on heating temperatures'
      @analysis_report.status = :fail
      @analysis_report.rating = 10.0
    else
      saving_kwh = @heating_model.kwh_saving_for_1_C_thermostat_reduction(start_date, asof_date)
      saving_£ = saving_kwh * ConvertKwh.scale_unit_from_kwh(:£, :gas)

      @analysis_report.summary = 'Advice on internal temperatures'
      text =  'Did you know you could save '
      text += FormatEnergyUnit.format(:£, saving_£)
      text += '(' + FormatEnergyUnit.format(:kwh, saving_kwh) + ') '
      text += 'if you reduced the temperature in the school by 1C'
      description1 = AlertDescriptionDetail.new(:text, text)
      @analysis_report.add_detail(description1)
      @analysis_report.rating = 10.0
      @analysis_report.status = :good
    end
  end
end