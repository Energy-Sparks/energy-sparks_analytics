#======================== Hot Water Efficiency =================================
require_relative 'alert_gas_model_base.rb'

class AlertHotWaterEfficiency < AlertGasModelBase
  MIN_EFFICIENCY = 0.7

  def initialize(school)
    super(school)
  end

  def analyse(asof_date)
    calculate_hot_water_model(asof_date)
    efficiency = @hot_water_model.efficiency

    report = AlertReport.new(:hotwaterefficiency)
    report.add_book_mark_to_base_url('HotWaterEfficiency')
    report.term = :longterm

    if efficiency < MIN_EFFICIENCY
      report.summary = 'Inefficient hot water system'
      text = 'Your hot water system appears to be only '
      text += sprintf('%.0f percent efficient', efficiency * 100.0)
      report.rating = 10.0 * (efficiency / 0.85)
      report.status = :poor
    else
      report.summary = 'Your hot water system is efficient'
      text = 'Your hot water system appears is '
      text += sprintf('%.0f percent efficient, which is very good', efficiency * 100.0)
      report.rating = 10.0
      report.status = :good
    end

    description1 = AlertDescriptionDetail.new(:text, text)
    report.add_detail(description1)
    add_report(report)
  end

  def calculate_hot_water_model(_as_of_date)
    @hot_water_model = AnalyseHeatingAndHotWater::HotwaterModel.new(@school)
  end
end