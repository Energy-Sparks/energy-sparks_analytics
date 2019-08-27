# rubocop:disable Metrics/LineLength, Style/FormatStringToken, Style/FormatString, Lint/UnneededDisable
#
# Alerts: Energy Sparks alerts
#         this is a mix of short-term alerts e.g. your energy consumption has gone up since last week
#         and longer term alerts - energy assessments e.g. your energy consumption at weekends it high
#
# the current code strcucture consists of an alert base class from which individual classes analysing
# different aspect of energy consumption are derived
#
# plus a reporting class for alerts which can return a mixture of text, html, charts etc., although
# much of the potential complexity of this framework will not be implemented in the first iteration
#

class AlertAnalysisBase
  include Logging

  ALERT_HELP_URL = 'https://blog.energysparks.uk/alerts'.freeze

  attr_reader :status, :rating, :term, :default_summary, :default_content, :bookmark_url
  attr_reader :analysis_date, :max_asofdate, :calculation_worked

  attr_reader :capital_cost, :one_year_saving_£, :ten_year_saving_£, :payback_years
  attr_reader :average_capital_cost, :average_one_year_saving_£, :average_payback_years

  attr_reader :time_of_year_relevance

  def initialize(school, report_type)
    @school = school
    @report_type = report_type
    @relevance = aggregate_meter.nil? ? :never_relevant : :relevant
    @not_enough_data_exception = false
    @calculation_worked = true
    @capital_cost = 0.0..0.0
    clear_model_cache
  end

  def relevance
    @relevance
  end

  def analyse(asof_date, use_max_meter_date_if_less_than_asof_date = false)
    begin
      @asof_date = asof_date
      @max_asofdate = maximum_alert_date
      if valid_alert?
        date = use_max_meter_date_if_less_than_asof_date ? [maximum_alert_date, asof_date].min : asof_date

        if @analysis_date.nil? || @analysis_date != date # only call once per date
          @analysis_date = date
          calculate(@analysis_date)
        end
      end
    rescue EnergySparksNotEnoughDataException => e
      logger.warn e.message
      logger.warn e.backtrace
      @not_enough_data_exception = true # TODO(PH, 31Jul2019) a mess for the moment, needs rationalising
    rescue StandardError => e
      @calculation_worked = false
      puts 
      puts e.to_s
      puts e.message
      puts e.backtrace
    end
  end

  def self.test_mode
    !ENV['ENERGYSPARKSTESTMODE'].nil? && ENV['ENERGYSPARKSTESTMODE'] == 'ON'
  end

  def raw_template_variables
    unformatted_template_variables
  end

  def html_template_variables
    formatted_template_variables(:html)
  end

  def text_template_variables
    formatted_template_variables(:text)
  end

  def self.flatten_front_end_template_variables
    variables = {}
    self.template_variables.each do |_group_name, variable_group|
      variables.merge!(variable_group)
    end
    variables
  end

  def self.priority_template_variables
    flatten_front_end_template_variables.select { |_name_sym, data| data.key?(:priority_code) }
  end

  def self.front_end_template_variables
    front_end_template = {}
    self.template_variables.each do |group_name, variable_group|
      map_types = {
        Float     => :float,
        Date      => :date,
        Time      => :datetime,
        String    => :string,
        Integer   => :integer,
        Symbol    => :symbol
      }
      front_end_template[group_name] = {}
      variable_group.each do |type, data|
        next if [:chart, :table, TrueClass].include?(data[:units])
        unless data[:units].is_a?(Symbol) || data[:units].is_a?(Hash)
          if map_types.key?(data[:units])
            data[:units] = map_types[data[:units]]
          else
            raise EnergySparksUnexpectedStateException.new("Missing maps for #{data[:units]} #{data}")
          end
        end
        if [:£_range, :years_range].include?(data[:units]) # convert range values into low and high versions
          front_end_template[group_name].merge!(front_end_high_low_range_values(convert_range_symbol_to_high(type), data, 'high'))
          front_end_template[group_name].merge!(front_end_high_low_range_values(convert_range_symbol_to_low(type),  data, 'low'))
        end
        front_end_template[group_name][type] = data
      end
    end
    front_end_template
  end

  # the front end needs the range type values split into high and low versions
  def self.front_end_high_low_range_values(high_low_type, data, high_low_description_suffix)
    {
      high_low_type => {
        description: data[:description] + ' ' + high_low_description_suffix,
        units: data[:units] == :£_range ? :£ : :years
      }
    }
  end

  def self.convert_range_symbol_to_high(type)
    (type.to_s + '_high').to_sym
  end

  def self.convert_range_symbol_to_low(type)
    (type.to_s + '_low').to_sym
  end

  def front_end_template_data
    lookup = flatten_template_variables
    raw_data = raw_template_variables
    list = text_template_variables.reject { |type, _value| [:chart, :table, TrueClass].include?(lookup[type][:units]) }
    list.merge(convert_range_template_data_to_high_low(list, lookup, raw_data))
  end

  private def convert_range_template_data_to_high_low(template_data, lookup, raw_data)
    new_data = {}
    template_data.each do |type, data| # front end want ranges as seperate high/low symbol-value pairs
      if [:£_range, :years_range].include?(lookup[type][:units])
        new_type = lookup[type][:units] == :£_range ? :£ : :years
        if raw_data[type].nil?
          new_data[self.class.convert_range_symbol_to_high(type)] = nil
          new_data[self.class.convert_range_symbol_to_low(type)]  = nil
        else
          new_data[self.class.convert_range_symbol_to_high(type)] = format(new_type, raw_data[type].first, :text, false, user_numeric_comprehension_level)
          new_data[self.class.convert_range_symbol_to_low(type)]  = format(new_type, raw_data[type].last,  :text, false, user_numeric_comprehension_level)
        end
      end
    end
    new_data
  end

  def raw_variables_for_saving
    raw = {}
    unformatted_template_variables.each do |type, data|
      raw[type] = data
      if data.is_a?(Range)
        raw[self.class.convert_range_symbol_to_low(type)] = data.first
        raw[self.class.convert_range_symbol_to_high(type)] = data.last
      elsif data.is_a?(Array)
        raw.merge!(flatten_table_for_saving(data))
        raw.delete(type)
      end
    end
    raw.transform_keys{ |k| self.class.name + ':' + k.to_s }
  end

  private def flatten_table_for_saving(table)
    data = {}
    header = table[0]
    (1...table.length).each do |row_index|
      (1...table[row_index].length).each do |column_index|
        key = self.class.name + ':' + table[row_index][0].to_s + ':' + header[column_index]
        value = table[row_index][column_index]
        data[key] = value.is_a?(TimeOfDay) ? value.to_s : value
      end
    end
    data
  end

  public_class_method def self.front_end_template_charts
    self.template_variable_by_type(:chart)
  end

  public_class_method def self.front_end_template_tables
    self.template_variable_by_type(:table)
  end

  def self.template_variable_by_type(var_type)
    charts = {}
    template_variables.each do |_group_name, variable_group|
      charts.merge!(variable_group.select { |_type, value| value[:units] == var_type })
    end
    charts
  end

  def front_end_template_chart_data
    charts = front_end_template_chart_data_by_type(:chart)
    charts.reject { |_name, definition| definition.empty? }
  end

  def front_end_template_table_data
    front_end_template_chart_data_by_type(:table)
  end

  private def front_end_template_chart_data_by_type(var_type)
    lookup = flatten_template_variables
    text_template_variables.select { |type, _value| lookup[type][:units] == var_type }
  end

  # inherited, so derived class has hash of 'name' => variables
  def self.template_variables
    { 'Common' => TEMPLATE_VARIABLES }
  end

  def summary_wording(format = :html)
    return nil if default_summary.nil? # remove once all new style alerts implemeted TODO(PH,13Mar2019)
    summary = AlertTemplateBinding.new(default_summary, formatted_template_variables(format), format)
    summary.bind
  end

  def content_wording(format = :html)
    return nil if default_content.nil? # remove once all new style alerts implemeted TODO(PH,13Mar2019)
    content = AlertTemplateBinding.new(default_content, formatted_template_variables(format), format)
    content.bind
  end

  TEMPLATE_VARIABLES = {
    relevance: {
      desciption: 'Relevance of a alert to a school at this point in time',
      units:  :relevance
    },
    analysis_date: {
      desciption: 'Latest date on which the alert data is based',
      units:  Date
    },
    status: {
      desciption: 'Status: good, bad, failed',
      units:  Symbol
    },
    rating: {
      desciption: 'Rating out of 10',
      units:  Float,
      priority_code:  'RATE'
    },
    term: {
      desciption: 'long term or short term',
      units:  Symbol
    },
    bookmark_url: {
      desciption: 'Link to help URL',
      units:  String
    },
    max_asofdate: {
      description: 'The latest date on which an alert can be run given the available data',
      units:  :date
    },
    pupils: {
      description: 'Number of pupils for relevant part of school on this date',
      units:  Integer
    },
    floor_area: {
      description: 'Floor area of relevant part of school',
      units:  :m2
    },
    school_type: {
      description: 'Primary or Secondary',
      units:  :school_type
    },
    school_name: {
      description: 'Name of school',
      units: String
    },
    urn: {
      desciption: 'School URN',
      units:  Integer
    },
    one_year_saving_£: {
      description: 'Estimated one year saving range',
      units: :£_range
    },
    average_one_year_saving_£: {
      description: 'Estimated one year saving range',
      units: :£,
      priority_code:  '1YRS'
    },
    ten_year_saving_£: {
      description: 'Estimated ten year saving range - typical capital investment horizon',
      units: :£_range
    },
    payback_years: {
      description: 'Payback in years',
      units: :years_range
    },
    average_payback_years: {
      description: 'Average payback in years',
      units: :years,
      priority_code:  'PAYB'
    },
    capital_cost: {
      description: 'Capital cost',
      units: :£_range,
    },
    average_capital_cost: {
      description: 'Average Capital cost',
      units: :£,
      priority_code:  'CAPC'
    },
    timescale: {
      description: 'Timescale of analysis e.g. week, month, year',
      units: String
    },
    time_of_year_relevance: {
      description: 'Rating: 10 = relevant to time of year, 0 = irrelevant, 5 = average/normal',
      units: Float,
      priority_code:  'TYRL'
    }
  }.freeze

  def maximum_alert_date
    raise EnergySparksAbstractBaseClass.new('Error: incorrect attempt to use abstract base class ' + self.class.name)
  end

  def timescale
    raise EnergySparksAbstractBaseClass.new('Error: incorrect attempt to use abstract base class for timeescale template variable ' + self.class.name)
  end

  protected def set_time_of_year_relevance(weight)
    @time_of_year_relevance = weight
  end

  def time_of_year_relevance
    set_time_of_year_relevance(5.0)
    # TODO(PH, 26Aug2019) - remove return in favour of raise once all derived classes defined
    # raise EnergySparksAbstractBaseClass, "Error: incorrect attempt to use abstract base class for time_of_year_relevance template variable #{self.class.name}"
  end

  # returns :enough, :not_enough, :minimum_might_not_be_accurate
  # depending on whether there is enough data to provide the alert
  def enough_data
    raise EnergySparksAbstractBaseClass.new('Error: incorrect attempt to use abstract base class for enough_data template variable ' + self.class.name)
  end

  def days_amr_data
    aggregate_meter.amr_data.end_date - aggregate_meter.amr_data.start_date + 1
  end

  def valid_alert?
    return false if @relevance == :never_relevant
    (!@school.aggregated_heat_meters.nil? && needs_gas_data?) ||
      (!@school.aggregated_electricity_meters.nil? && needs_electricity_data?)
  end

  def make_available_to_users?
    result = relevance == :relevant && enough_data == :enough && calculation_worked
    logger.info "Alert #{self.class.name} not being made available to users: reason: #{relevance} #{enough_data} #{calculation_worked}" if !result
    result
  end

  def self.print_all_formatted_template_variable_values
    puts 'Available variables and values:'
    self.template_variables.each do |group_name, variable_group|
      puts "  #{group_name}"
      variable_group.each do |type, data|
        # next if data[:units] == :table
        value = send(type)
        formatted_value = format(data[:units], value, :html, false, user_numeric_comprehension_level)
        puts sprintf('    %-40.40s %-20.20s', type, formatted_value) + ' ' + data.to_s
      end
    end
  end

  private

  def formatted_template_variables(format = :html)
    variable_list(true, format)
  end

  def unformatted_template_variables
    variable_list(false)
  end

  protected def calculate_rating_from_range(good_value, bad_value, actual_value)
    [10.0 * [(actual_value - bad_value) / (good_value - bad_value), 0.0].max, 10.0].min.round(1)
  end

  protected def flatten_template_variables
    list = {}
    self.class.template_variables.each do |_group_name, variable_group|
      variable_group.each do |type, data|
        list[type] = data
      end
    end
    list
  end

  def variable_data_types
    list = {}
    flatten_template_variables.each do |type, data|
      list[type] = data[:units]
    end
    list
  end

  private def variable_list(formatted, format = :text)
    list = {}
    flatten_template_variables.each do |type, data|
      begin
        if [TrueClass, FalseClass].include?(data[:units])
          list[type] = send(type) # don't reformat flags so can be bound in if tests
        elsif data[:units] == :table
          list[type] = format_table(type, data, formatted, format)
        else
          if respond_to?(type, true)
            if formatted && send(type).nil?
              list[type] = ''
            else
              list[type] = formatted ? format(data[:units], send(type), format, false, user_numeric_comprehension_level) : send(type)
            end
          else
            logger.info "Warning: alert doesnt implement #{type}"
          end
        end
      rescue StandardError => e
        list[type] = e.message
      end
    end
    list
  end

  # convert a table either into an html table, or a '|' bar seperated text table; can't use commas as contined in 1,234 numbers
  private def format_table(type, data_description, formatted, format)
    header, formatted_data = format_table_data(type, data_description, formatted, format)
    return nil if formatted_data.nil?
    table_formatter = AlertRenderTable.new(header, formatted_data)
    table_formatter.render(format)
  end

  protected def user_numeric_comprehension_level
    :ks2
  end

  protected def format(unit, value, format, in_table, level)
    FormatUnit.format(unit, value, format, true, in_table, level)
  end

  # convert the cells within a table into formatted html or text
  private def format_table_data(type, data_description, formatted, format)
    formatted_table = []
    return [nil, nil] unless respond_to? type
    table_data = send(type)
    return [data_description[:header], nil] if table_data.nil?
    column_formats = data_description[:column_types]
    table_data.each do |row_data|
      formatted_row = []
      row_data.each_with_index do |val, index|
        formatted_val = formatted ? format(column_formats[index], val, format, true, user_numeric_comprehension_level) : val
        formatted_row.push(formatted_val)
      end
      formatted_table.push(formatted_row)
    end
    [data_description[:header], formatted_table]
  end

  protected

  def add_book_mark_to_base_url(bookmark)
    @help_url = ALERT_HELP_URL + '#' + bookmark
  end

  def calculate_payback_years_deprecated
    return (0.0..0.0) if one_year_saving_£.nil? || capital_cost.nil? || capital_cost == (0.0..0.0)
    min_saving = one_year_saving_£.last.nil? ? 0.0 : capital_cost.first / one_year_saving_£.last
    max_saving = one_year_saving_£.first.nil? ?  0.0 : capital_cost.last / one_year_saving_£.first
    Range.new(min_saving, max_saving)
  end

  def set_savings_capital_costs_payback(one_year_saving_£, capital_cost)
    one_year_saving_£ = Range.new(one_year_saving_£, one_year_saving_£) if one_year_saving_£.is_a?(Float)
    capital_cost = Range.new(capital_cost, capital_cost) if capital_cost.is_a?(Float)
    @capital_cost = capital_cost
    @average_capital_cost = capital_cost.nil? ? 0.0 : ((capital_cost.first + capital_cost.last)/ 2.0)

    @one_year_saving_£ = one_year_saving_£
    @ten_year_saving_£ = one_year_saving_£.nil? ? 0.0 : Range.new(one_year_saving_£.first * 10.0, one_year_saving_£.last * 10.0)
    @average_one_year_saving_£ = one_year_saving_£.nil? ? 0.0 : ((one_year_saving_£.first + one_year_saving_£.last) / 2.0)

    @average_payback_years = (@one_year_saving_£.nil? || @one_year_saving_£ == 0.0 || @average_capital_cost.nil?) ? 0.0 : @average_capital_cost / @average_one_year_saving_£
  end

  def pupils
    if @school.respond_to?(:number_of_pupils) && @school.number_of_pupils > 0
      @school.number_of_pupils
    elsif @school.respond_to?(:school) && !@school.school.number_of_pupils > 0
      @school.school.number_of_pupils
    else
      raise EnergySparksBadDataException.new('Unable to find number of pupils for alerts')
    end
  end

  def floor_area
    if @school.respond_to?(:floor_area) && !@school.floor_area.nil? && @school.floor_area > 0.0
      @school.floor_area
    elsif @school.respond_to?(:school) && !@school.school.floor_area.nil? && @school.school.floor_area > 0.0
      @school.school.floor_area
    else
      raise EnergySparksBadDataException.new('Unable to find number of floor_area for alerts')
    end
  end

  def school_name
    if @school.respond_to?(:name) && !@school.name.nil?
      @school.name
    elsif @school.respond_to?(:name) && !@school.school.name.nil?
      @school.school.name
    else
      raise EnergySparksBadDataException.new('Unable to find school name for alerts')
    end
  end

  def urn
    @school.urn
  end

  def school_type
    if @school.respond_to?(:school_type) && !@school.school_type.nil?
      @school.school_type.instance_of?(String) ? @school.school_type.to_sym : @school.school_type
    elsif @school.respond_to?(:school) && !@school.school.school_type.nil?
      @school.school.school_type.instance_of?(String) ? @school.school.school_type.to_sym : @school.school.school_type
    else
      raise EnergySparksBadDataException.new("Unable to find number of school_type for alerts #{@school.school_type} #{@school.school.school_type}")
    end
  end

  protected def holiday?(date)
    @school.holidays.holiday?(date)
  end

  protected def weekend?(date)
    date.saturday? || date.sunday?
  end

  protected def occupied?(date)
    !(weekend?(date) || holiday?(date))
  end

  protected def occupancy_description(date)
    holiday?(date) ? 'holiday' : weekend?(date) ? 'weekend' : 'school day'
  end

  # returns a list of the last n 'school_days' before and including the asof_date
  def last_n_school_days(asof_date, school_days)
    list_of_school_days = []
    while school_days > 0
      if occupied?(asof_date)
        list_of_school_days.push(asof_date)
        school_days -= 1
      end
      asof_date -= 1
    end
    list_of_school_days.sort
  end

  def needs_gas_data?
    true
  end

  def needs_electricity_data?
    true
  end

  protected def meter_date_up_to_one_year_before(meter, asof_date)
    [asof_date - 365, meter.amr_data.start_date].max
  end

  protected def kwh_date_range(meter, start_date, end_date, data_type = :kwh)
    return nil if meter.amr_data.start_date > start_date || meter.amr_data.end_date < end_date
    meter.amr_data.kwh_date_range(start_date, end_date, data_type)
  end

  protected def kwhs_date_range(meter, start_date, end_date, data_type = :kwh)
    return nil if meter.amr_data.start_date > start_date || meter.amr_data.end_date < end_date
    (start_date..end_date).to_a.map { |date| meter.amr_data.one_day_kwh(date, data_type) }
  end

  protected def kwh(date1, date2, data_type = :kwh)
    aggregate_meter.amr_data.kwh_date_range(date1, date2, data_type)
  end

  protected def meter_date_one_year_before(meter, asof_date)
    meter_date_up_to_one_year_before(meter, asof_date)
  end

  protected def annual_kwh(meter, asof_date)
    start_date = meter_date_one_year_before(meter, asof_date)
    kwh(start_date, asof_date) * scale_up_to_one_year(meter, asof_date)
  end

  protected def scale_up_to_one_year(meter, asof_date)
    365.0 / (asof_date - meter_date_one_year_before(meter, asof_date))
  end

  private

  def calculate(asof_date)
    raise EnergySparksAbstractBaseClass, 'Error: incorrect attempt to use abstract base class'
  end

  # the model cache cached at the aggregate meter and therefore the school level
  # if in the analystics enronment we are running slightly different (asof_date v. chart_date)
  # then clear the cache, however, then does further caching if in 'test' mode
  private def clear_model_cache
    @school.aggregated_heat_meters.model_cache.clear_model_cache unless @school.aggregated_heat_meters.nil?
  end

  public

  # slightly iffy way of creating short codes for alert class names
  def self.alert_short_code(alert_class)
    alert_class.to_s.split(//).select { |char| ('A'..'Z').include?(char) }[1..8].join
  end

  def self.short_code_alert(short_code)
    matching_alerts = all_available_alerts.select { |available_alert| alert_short_code(available_alert) == short_code }
    raise EnergySparksUnexpectedStateException, "Only expected one matching short code for #{short_code}, got #{matching_alerts.length}" if matching_alerts.length != 1
    matching_alerts.first
  end

  def self.all_available_alerts
    [
      AlertChangeInDailyElectricityShortTerm,
      AlertChangeInDailyGasShortTerm,
      AlertChangeInElectricityBaseloadShortTerm,
      AlertElectricityAnnualVersusBenchmark,
      AlertElectricityBaseloadVersusBenchmark,
      AlertGasAnnualVersusBenchmark,
      AlertHeatingComingOnTooEarly,
      AlertHeatingOnOff,
      AlertHeatingSensitivityAdvice,
      AlertHotWaterEfficiency,
      AlertImpendingHoliday,
      AlertHeatingOnNonSchoolDays,
      AlertOutOfHoursElectricityUsage,
      AlertOutOfHoursGasUsage,
      AlertHotWaterInsulationAdvice,
      AlertHeatingOnSchoolDays,
      AlertThermostaticControl,
      AlertWeekendGasConsumptionShortTerm,
      AlertElectricityMeterConsolidationOpportunity,
      AlertGasMeterConsolidationOpportunity,
      AlertMeterASCLimit,
      AlertDifferentialTariffOpportunity,
      AlertSchoolWeekComparisonElectricity,
      AlertPreviousHolidayComparisonElectricity,
      AlertPreviousYearHolidayComparisonElectricity,
      AlertSchoolWeekComparisonGas,
      AlertPreviousHolidayComparisonGas,
      AlertPreviousYearHolidayComparisonGas,
      AlertAdditionalPrioritisationData
    ]
  end
end