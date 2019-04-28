#======================== Heating Sensitivity Advice ==============
require_relative 'alert_gas_model_base.rb'

class AlertHeatingSensitivityAdvice < AlertGasModelBase
  attr_reader :annual_saving_1_C_change_kwh, :annual_saving_1_C_change_£, :annual_saving_1_C_change_percent
  attr_reader :one_year_saving_£

  def initialize(school)
    super(school, :heatingsensitivity)
  end

  def self.template_variables
    specific = {'Temperature change advice' => TEMPLATE_VARIABLES}
    specific.merge(self.superclass.template_variables)
  end

  def timescale
    'year'
  end

  TEMPLATE_VARIABLES = {
    annual_saving_1_C_change_kwh: {
      description: 'Predicted annual reduction in heating consumption if thermostat turned down 1C (kWh)',
      units:  {kwh: :gas}
    },
    annual_saving_1_C_change_£: {
      description: 'Predicted annual reduction in heating consumption if thermostat turned down 1C (£)',
      units:  :£
    },
    annual_saving_1_C_change_percent: {
      description: 'Predicted annual reduction in heating consumption if thermostat turned down 1C (% of annual gas consumption)',
      units:  :percent
    },
  }

  private def calculate(asof_date)
    start_date = [asof_date - 365, @school.aggregated_heat_meters.amr_data.start_date].max
    @months = ((asof_date - start_date) / 30.0).floor
    @annual_saving_1_C_change_kwh = @heating_model.kwh_saving_for_1_C_thermostat_reduction(start_date, asof_date)
    @annual_kwh = kwh(start_date, asof_date)
    @annual_saving_1_C_change_percent = @annual_saving_1_C_change_kwh / @annual_kwh
    @annual_saving_1_C_change_kwh *= (365 / (asof_date - start_date)) # scale to 1 year
    @annual_saving_1_C_change_£ = @annual_saving_1_C_change_kwh * BenchmarkMetrics::GAS_PRICE
    @one_year_saving_£ = Range.new(@annual_saving_1_C_change_£, @annual_saving_1_C_change_£)
  end

  def analyse_private(asof_date)
    calculate_model(asof_date)
    calculate(asof_date)

    # @analysis_report.add_book_mark_to_base_url('ThermostaticControl')
    @analysis_report.term = :longterm

    if @months < 12
      @analysis_report.summary = 'Not enough (<1 year) historic gas data to provide advice on heating temperatures'
      @analysis_report.status = :fail
      @analysis_report.rating = 10.0
    else
      summary_text = 'Did you know you could save ' + FormatEnergyUnit.format(:£, @annual_saving_1_C_change_£) +
                      ' if you reduced the temperature in the school by 1C?'
      @analysis_report.summary = summary_text
      text =  'Did you know you could save '
      text += FormatEnergyUnit.format(:£, @annual_saving_1_C_change_£)
      text += '(' + FormatEnergyUnit.format(:kwh, @annual_saving_1_C_change_kwh) + ') '
      text += 'if you reduced the temperature in the school by 1C'
      description1 = AlertDescriptionDetail.new(:text, text)
      @analysis_report.add_detail(description1)
      @analysis_report.rating = 10.0
      @analysis_report.status = :good
    end
  end
end