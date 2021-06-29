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
      { type: :html, content: common_causes_html },
      { type: :html, content: what_to_do_html },
      AlertBaseloadBase.baseload_alerts.map{ |alert_class| alert_class.background_and_advice_on_reducing_issue }
    ].flatten
  end

  def evaluation_table_html
    header = ['Measure', 'Comments', 'Potential saving', 'Rating']
    rows = valid_alerts.map do |alert, valid|
      [
        alert.analysis_description,
        alert.evaluation_html,
        FormatEnergyUnit.format(:£, alert.average_one_year_saving_£, :html),
        start_ratings_html(alert.rating)
      ]
    end
    HtmlTableFormatting.new(header, rows).html(right_justified_columns: [2])
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

  # TODO(PH, 28Jun2021) move somewhere more appropriate if it works in FE
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
        and reducing its carbon footprint. At a well-managed school the baseload should remain the same
        throughout the year. Every 1 kW of baseload reduced will save a school £1,300 per year.
      </p>
    )
  end

  def self.common_causes_html
    %(
      <h3>Common causes</h3>
      A high baseload is often caused by:
      <ul>
        <li>Old freezers and fridges running constantly</li>
        <li>Inefficient IT servers</li>
        <li>Security lights</li> 
        <li>Electric water heaters</li>
        <li>Water chillers</li>
        <li>Air conditioning</li>
        <li>Computers, whiteboards and other electrical equipment left running when the school is closed.</li>
      </ul>
    )
  end

  def self.what_to_do_html
    %(
      <h3>What you should do</h3>
      Reducing a school's baseload is often the fastest way of reducing a school's
      energy costs and reducing its carbon footprint. For each 1kW reduction in baseload,
      the school will save £1,300 per year, and reduce its carbon footprint by 1,800 kg.
      <ul>
        <li>Find out whether any electrical equipment or lights are running all the time.
            Do they need to run all the time?</li>
        <li>You should check to see what lights and appliances are left on at the end of the school day
            and get pupils and staff to switch off lights and appliances when they go home,
            and before the school holidays. Don't forget to look in offices or school kitchens.</li> 
        <li>Use appliance monitors to check how much energy your school fridges and freezers are using,
            as these need to run all the time. A modern fridge or freezer uses £35 to £45 of electricity a year,
            but old models can use up to £600 of electricity a year.</li>
        <li>Consider replacing old ICT servers with modern servers or move to saving your school's
            data in the 'cloud'. Removing the need for school ICT servers can also save energy previously
            used for air conditioning in school server rooms.</li>
      </ul>
    )
  end

  def more_information_at_bottom_of_page_html
    %(
      More detailed advice on reducing this baseload costs is provided at
      the bottom of the page.
    )
  end
end
