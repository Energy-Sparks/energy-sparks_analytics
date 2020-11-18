class ManagementSummaryTable < ContentBase
  MAX_DAYS_OUT_OF_DATE_FOR_4_WEEK_COMPARISON = 2 * 7
  MAX_DAYS_OUT_OF_DATE_FOR_1_YEAR_COMPARISON = 3 * 30
  NO_RECENT_DATA_MESSAGE = 'no recent data'
  NOT_ENOUGH_DATA_MESSAGE = 'not enough data'
  INCREASED_MESSAGE = 'increased'
  DECREASED_MESSAGE = 'decreased'
  NON_NUMERIC_DATA = [
    NO_RECENT_DATA_MESSAGE,
    NOT_ENOUGH_DATA_MESSAGE,
    INCREASED_MESSAGE,
    DECREASED_MESSAGE
  ]
  attr_reader :scalar
  attr_reader :summary_table
  attr_reader :calculation_worked

  def initialize(school)
    super(school)
    @scalar = ScalarkWhCO2CostValues.new(@school)
    @rating = nil
  end

  def valid_alert?
    true
  end

  def rating
    5.0
  end

  def self.header_html
    [
      '',
      'Annual Use (kWh)',
      'Annual CO2 (kg)',
      'Annual Cost',
      'Change from last year',
      'Change in last 4 school weeks',
      'Potential savings',
    ] 
  end

  def self.header_text
    text_header = header_html.map { |col_header| col_header.gsub('&pound;', '£') }
    text_header.map { |col_header| col_header.gsub('&percnt;', '%') }
  end

  def self.template_variables
    { 'Head teacher\'s energy summary' => TEMPLATE_VARIABLES}
  end

  KWH_NOT_ENOUGH_IN_COL_FORMAT = { units: :kwh, substitute_nil: 'Not enough data' }

  COLUMN_TYPES = [
    :fuel_type,
    KWH_NOT_ENOUGH_IN_COL_FORMAT,
    :co2,
    :£,
    :relative_percent, # or text saying 'No recent data'
    :relative_percent, # or text saying 'No recent data'
    :£
  ] # needs to be kept in sync with instance table
  
  TEMPLATE_VARIABLES = {
    summary_table: {
      description: 'Summary of annual per fuel consumption, annual change, 4 week change, saving to exemplar',
      units:          :table,
      header:         header_text,
      column_types:   COLUMN_TYPES 
    }
  }

  def analyse(_asof_date)
    calculate
  end

  def check_relevance
    true
  end

  def enough_data
    :enough
  end

  def relevance
    :relevant
  end

  def html
    HtmlTableFormatting.new(self.class.header_html, format_rows(data_by_fuel_type)).html
  end
  
  def values_for_fuel_type(fuel_type)
    last_4_week_comparison  = compare_two_periods(fuel_type, { schoolweek: -3..0 }, { schoolweek: -7..-4 }, MAX_DAYS_OUT_OF_DATE_FOR_4_WEEK_COMPARISON)
    last_2_years_comparison = compare_two_periods(fuel_type, { year: 0 }, { year: -1 }, MAX_DAYS_OUT_OF_DATE_FOR_1_YEAR_COMPARISON)
    difference = difference_to_exemplar_£(last_2_years_comparison[:current_£], fuel_type)

    {
      fuel_type:          { data: fuel_type.to_s.humanize.capitalize,       units: :fuel_type },
      this_year_kwh:      { data: last_2_years_comparison[:current_kwh],    units: KWH_NOT_ENOUGH_IN_COL_FORMAT },
      this_year_co2:      { data: last_2_years_comparison[:current_co2],    units: :co2 },
      this_year_£:        { data: last_2_years_comparison[:current_£],      units: :£ },
      change_years:       { data: last_2_years_comparison[:percent_change], units: :relative_percent },
      change_4_weeks:     { data: last_4_week_comparison[:percent_change],  units: :relative_percent },
      examplar_benefit:   { data: difference,                               units: :£ }
    }
  end

  private

  def calculate
    @summary_table = format_rows(data_by_fuel_type, :raw)
    @calculation_worked = true
  end

  def data_by_fuel_type
    @school.fuel_types(false).map do |fuel_type|
      values_for_fuel_type(fuel_type)
    end
  end

  protected def format(unit, value, format, in_table, level)
    return value if NON_NUMERIC_DATA.include?(value)  # bypass front end auto cell table formatting
    FormatUnit.format(unit, value, format, true, in_table, level)
  end

  def format_rows(rows, medium = :html)
    rows.map do |row|
      row.map do |_field_name, field|
        if !field[:data].nil? && (field[:data] == NO_RECENT_DATA_MESSAGE || field[:data] == INCREASED_MESSAGE || field[:data] == DECREASED_MESSAGE)
          field[:data]
        elsif field[:data].nil?
          NOT_ENOUGH_DATA_MESSAGE
        else
          FormatEnergyUnit.format(field[:units], field[:data], medium, false, false) rescue 'error'
        end
      end
    end
  end

  def difference_to_exemplar_£(actual_£, fuel_type)
    return nil if actual_£.nil?
    examplar = BenchmarkMetrics.exemplar_£(@school, fuel_type, nil, nil)
    [actual_£ - examplar, 0.0].max
  end

  def compare_two_periods(fuel_type, period1, period2, max_days_out_of_date)
    current_period_kwh  = checked_get_aggregate(period1, fuel_type, :kwh)
    current_period_co2  = checked_get_aggregate(period1, fuel_type, :co2)
    current_period_co2  = electricity_co2_with_solar_offset if @school.solar_pv_panels? && fuel_type == :electricity
    current_period      = checked_get_aggregate(period1, fuel_type, :£)
    previous_period     = checked_get_aggregate(period2, fuel_type, :£)
    out_of_date         = comparison_out_of_date(period1, fuel_type, max_days_out_of_date)
    percent_change      = (current_period.nil? || previous_period.nil? || out_of_date) ? nil : percent_change_with_zero(current_period, previous_period) 
    
    { 
      current_kwh:    current_period_kwh,
      current_co2:    current_period_co2,
      current_£:      current_period, 
      previous_£:     previous_period, 
      percent_change: out_of_date ? NO_RECENT_DATA_MESSAGE : percent_change,
     }
  end

  def percent_change_with_zero(current_period, previous_period)
    if current_period == previous_period
      0.0
    elsif previous_period == 0.0
      INCREASED_MESSAGE
    elsif current_period == 0.0
      DECREASED_MESSAGE
    else
      (current_period - previous_period)/previous_period
    end
  end

  def checked_get_aggregate(period, fuel_type, data_type, max_days_out_of_date = nil)
    begin
      scalar.aggregate_value(period, fuel_type, data_type, nil, max_days_out_of_date)
    rescue EnergySparksNotEnoughDataException => _e
      nil
    end
  end

  def electricity_co2_with_solar_offset
    scalar = ScalarkWhCO2CostValues.new(@school)
    consumption   = checked_get_aggregate({ year: 0}, :electricity, :co2)
    pv_production = checked_get_aggregate({ year: 0}, :solar_pv,    :co2)
    net_co2 = consumption.nil? || pv_production.nil? ? nil : (consumption - pv_production)
  end

  def comparison_out_of_date(period1, fuel_type, max_days_out_of_date)
    begin
      checked_get_aggregate(period1, fuel_type, :kwh, max_days_out_of_date)
      false
    rescue EnergySparksMeterDataTooOutOfDate => _e
      true
    end
  end
end

# old name for backwards compatibility with front end
class HeadTeachersSchoolSummaryTable < ManagementSummaryTable
end