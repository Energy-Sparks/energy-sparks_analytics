class AdviceBaseloadCommentary
  def initialize(school, meter)
    @school = school
    @meter = meter
  end

  def all_commentary
    advice = [ { type: :html, content: '<b>Comments:</b>' } ]
    advice += html_unordered_list(valid_alerts.map{ |alert| alert.commentary }.flatten)
    advice.push( { type: :html, content: evaluation_table_html } ) 
    advice.push( { type: :html, content: more_information_at_bottom_of_page_html } )
    advice.flatten
  end

  def self.all_background_and_advice_on_reducing_issues
    [
      { type: :html, content: '<h2>How to reduce your baseload</h2>' },
      { type: :html, content: general_advice_html },
      AlertBaseloadBase.baseload_alerts.map{ |alert_class| alert_class.background_and_advice_on_reducing_issue }
    ].flatten
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

  def html_unordered_list(items)
    html = '<ul>'
    items.each do |item|
      html += "<li> #{item[:content]}</li>"
    end
    html += '</ul>'
    [{ type: :html, content: html } ]
  end

  def valid_alerts
    alerts.select { |alert, valid| valid }.keys
  end

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

  def self.general_advice_html
    %(
      <p>
        Reducing a school's baseload is often the fastest way of reducing a school's energy costs
        and reducing its carbon footprint. At a well-managed school the baseload should remain the same (flat)
        throughout the year.
      </p>
    )
  end

  def more_information_at_bottom_of_page_html
    %(
      More detailed advice on reducing this inconsistency is provided at
      the bottom of the page.
    )
  end
end
