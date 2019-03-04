#======================== Heating Sensitivity Advice ==============
require_relative 'alert_gas_model_base.rb'

class AlertHotWaterInsulationAdvice < AlertGasModelBase
  attr_reader :kwh_per_1_C

  def initialize(school)
    super(school, :hotwaterinsulation)
  end

  def analyse_private(asof_date)
    calculate_model(asof_date)

    start_date = [asof_date - 365, @school.aggregated_heat_meters.amr_data.start_date].max
    # @analysis_report.add_book_mark_to_base_url('ThermostaticControl')
    @analysis_report.term = :longterm

    months = ((asof_date - start_date) / 30.0).floor

    if months < 12
      @analysis_report.summary = 'Not enough (<1 year) historic gas data to provide advice on hot water insulation losses'
      @analysis_report.status = :fail
      @analysis_report.rating = 10.0
    else
      saving_kwh, percent_loss = @heating_model.hot_water_poor_insulation_cost_kwh(start_date, asof_date)
      saving_£ = saving_kwh * ConvertKwh.scale_unit_from_kwh(:£, :gas)

      @analysis_report.summary = 'Advice the insulation of your hot water system'
      text =  'Energy Sparks has analysed the sensitivity of your hot water consumption to outside '
      text += 'temperatures and estimates '
      text += FormatEnergyUnit.format(:£, saving_£)
      text += '(' + FormatEnergyUnit.format(:kwh, saving_kwh) + ') '
      text += ' each year is lost in your hot water system as temperatures get colder '
      text += ' likely because of poor insulation. '
      text += sprintf('This is about %.0f percent of your annual hot water consumption.', percent_loss * 100.0)
      description1 = AlertDescriptionDetail.new(:text, text)
      @analysis_report.add_detail(description1)
      @analysis_report.rating = ((1.0 - percent_loss) * 10.0).round(0)
      @analysis_report.status = @analysis_report.rating > 3.0 ? :good : :bad
    end
  end
end
