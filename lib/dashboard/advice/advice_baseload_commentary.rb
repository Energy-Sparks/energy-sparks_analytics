class AdviceBaseloadCommentary
  def initialize(school, meter)
    @meter = meter
  end

  def all_commentary
    advice = []
    alerts.each do |alert, valid|
      advice.push(alert.commentary) if valid
    end
    advice
    # charts_and_html.push( { type: :chart_name, content: :electricity_baseload_by_day_of_week } )
    # charts_and_html.push( { type: :html,  content: chart_seasonal_trend_comment } )
  end

  private

  def alerts
    @alerts ||= AlertBaseloadBase.new(school, :baseloadadvicecommentary, meter).calculate_all_baseload_alerts(@meter.amr_data.end_date)
  end
end
