class ChartTimeScaleDescriptions
  def initialize(chart_config)
    @chart_config = chart_config
  end

  TIME_SCALE_TYPES = { 
    year:           'year',
    years:          'long term',
    academicyear:   'academic year',
    month:          'month',
    holiday:        'holiday',
    includeholiday: 'holiday',
    week:           'week',
    workweek:       'week',
    schoolweek:     'school week',
    day:            'day',
    frostday:       'frosty day',
    frostday_3:     'frosty day',
    diurnal:        'day with large diurnal range',
    optimum_start:  'optimum start example day',
    daterange:      'date range',
    hotwater:       'summer period with hot water usage',
    none:           ''
  }.freeze

  def self.timescale_name(timescale_symbol) # also used by drilldown
    TIME_SCALE_TYPES.key?(timescale_symbol) ? TIME_SCALE_TYPES[timescale_symbol] : TIME_SCALE_TYPES[:none] 
  end

  def self.convert_timescale_to_array(timescale)
    timescales = []
    if timescale.is_a?(Symbol)
      timescales = [ {timescale => 0}]
    elsif timescale.is_a?(Hash)
      timescales = [ timescale ]
    elsif timescale.is_a?(Array)
      timescales = timescale
    else
      raise EnergySparksUnexpectedStateException, "Unsupported timescale #{timescale} for chart manipulation"
    end
    timescales
  end

  public def timescale_description
    self.class.interpret_timescale_description(@chart_config[:timescale])
  end

  def self.interpret_timescale_description(timescale)
    timescales = convert_timescale_to_array(timescale)
    timescale = timescales[0]
    if timescale.is_a?(Hash) && !timescale.empty? && timescale.keys[0] == :daterange
      impute_description_from_date_range(timescale.values[0])
    elsif TIME_SCALE_TYPES.key?(timescale)
      timescale_name(timescale)
    elsif timescale.is_a?(Hash) && !timescale.empty? && TIME_SCALE_TYPES.key?(timescale.keys[0])
      timescale_name(timescale.keys[0])
    else
      'period'
    end
  end

  def self.days_in_date_range(daterange)
    (daterange.last - daterange.first + (daterange.exclude_end? ? 0 : 1)).to_i
  end

  def self.impute_description_from_date_range(date_range)
    days = days_in_date_range(date_range)
    case days
    when 1
      timescale_name(:day)
    when 7
      timescale_name(:week)
    when 28..31
      timescale_name(:month)
    when 350..380
      timescale_name(:year)
    else
      if days > 380
        timescale_name(:years)
      elsif days % 7 == 0
        "#{days / 7} weeks" # ends up with duplicate number e.g. 'Move forward 1 2 weeks' TODO(PH, 13Sep2019) fix further up hierarchy
      else
        timescale_name(:daterange)
      end
    end
  end
end