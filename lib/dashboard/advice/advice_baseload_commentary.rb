class AdviceBaseloadCommentary
  def initialize(school, meter)
    @school = school
    @meter = meter
  end

  def all_commentary
    advice = []
    alerts.each do |alert, valid|
      advice.push(alert.commentary) if valid
    end
    advice.push( { type: :html, content: evaluation_table_html } ) 
    advice
    # charts_and_html.push( { type: :chart_name, content: :electricity_baseload_by_day_of_week } )
    # charts_and_html.push( { type: :html,  content: chart_seasonal_trend_comment } )
  end

  def evaluation_table_html
    header = ['Measure', 'Rating', 'Potential saving']
    rows = alerts.map do |alert, valid|
      [
        alert.class.name,
        start_ratings_html(alert.rating),
        FormatEnergyUnit.format(:£, alert.average_one_year_saving_£, :html)
      ]
    end
    HtmlTableFormatting.new(header, rows).html
  end

  private

  # TODO(PH, 28Jun2021) move seomwhere more appropriate if it works
  def start_ratings_html(r)
    stars = r / 2.0 # ratings 0 to 10, starts 0 to 5
    prefix = '<span class="stars float-right ml-2">'
    whole_stars = stars.floor
    part_stars = (stars - whole_stars).between?(0.25, 0.75) ? 1 : 0
    empty_stars = 5 - whole_stars - part_stars
    html_stars = ''
    html_stars += '<i class="fas fa-star"></i>' * whole_stars
    html_stars += '<i class="fas fa-star-half-alt"></i>' * part_stars
    html_stars += '<i class="far fa-star"></i>' * empty_stars
    postfix = '</span>'
    prefix + html_stars + postfix
  end

  def alerts
    @alerts ||= AlertBaseloadBase.new(@school, :baseloadadvicecommentary, @meter).calculate_all_baseload_alerts(@meter.amr_data.end_date)
  end
end
