#======================== Hot Water Efficiency =================================
require_relative 'alert_gas_model_base.rb'

class AlertHotWaterEfficiency < AlertGasModelBase
  MIN_EFFICIENCY = 0.7

  def initialize(school)
    super(school, :hotwaterefficiency)
  end

  private def calculate(asof_date)
    super(asof_date)
    calculate_hot_water_model(asof_date)
  end

  def analyse_private(asof_date)
    calculate(asof_date)
    
    efficiency = @hot_water_model.overall_efficiency

    @analysis_report.add_book_mark_to_base_url('HotWaterEfficiency')
    @analysis_report.term = :longterm

    if efficiency < MIN_EFFICIENCY
      @analysis_report.summary = 'Inefficient hot water system'
      text = 'Your hot water system appears to be only '
      text += sprintf('%.0f percent efficient.', efficiency * 100.0)
      @analysis_report.rating = 10.0 * (efficiency / 0.85)
      @analysis_report.status = :poor
    else
      @analysis_report.summary = 'Your hot water system is efficient'
      text = 'Your hot water system appears is '
      text += sprintf('%.0f percent efficient, which is very good.', efficiency * 100.0)
      @analysis_report.rating = 10.0
      @analysis_report.status = :good
    end

    description1 = AlertDescriptionDetail.new(:text, text)
    @analysis_report.add_detail(description1)
  end

  def calculate_hot_water_model(_as_of_date)
    @hot_water_model = AnalyseHeatingAndHotWater::HotwaterModel.new(@school)
  end
end