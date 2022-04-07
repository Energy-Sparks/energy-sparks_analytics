# formatting of 2 year monthly grouped targetting and tracking
class TargetingAndTrackingTable < ContentBase

  attr_reader :scalar
  attr_reader :summary_table
  attr_reader :calculation_worked

  def initialize(school, fuel_type)
    super(school)

    @fuel_type = fuel_type
    @rating = nil
  end

  def valid_alert?
    true
  end

  def self.template_variables
    { 'Targeting and tracking summary' => TEMPLATE_VARIABLES}
  end
  
  TEMPLATE_VARIABLES = {
    summary_table: {
      description: 'Targeting and tracking summary',
      units:          :table,
      header:         ['unknown - dynamic not static'],
      column_types:   [String] 
    }
  }

  ALL_TABLE_ROWS_CONFIG = {
    # previous_year_kwhs:                 { name: 'Previous year(kWh)',             datatype: :kwh },
    current_year_kwhs:                  { name: 'Current year(kWh)',              datatype: :kwh },
    # full_cumulative_previous_year_kwhs: { name: 'Previous year: cumulative(kWh)', datatype: :kwh },
    full_cumulative_current_year_kwhs:  { name: 'Current year: cumulative(kWh)',  datatype: :kwh },
    full_targets_kwh:                   { name: 'Target(kWh): full',              datatype: :kwh },
    partial_targets_kwh:                { name: 'Target(kWh): partial',           datatype: :kwh },
    full_cumulative_targets_kwhs:       { name: 'Cumulative target(kWh): full',   datatype: :kwh },
    partial_cumulative_targets_kwhs:    { name: 'Cumulative target(kWh): partial',datatype: :kwh },
    monthly_performance:                { name: 'Monthly performance',            datatype: :relative_percent },
    cumulative_performance:             { name: 'Cumulative performance',         datatype: :relative_percent },
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

  def full_table_html
    rows = select_rows(nil)
    html_table_formatting(header, rows)
  end

  def simple_culmulative_target_table_html
    rows = select_rows(
      %i[
        full_cumulative_targets_kwhs
        full_cumulative_current_year_kwhs
        cumulative_performance
      ]
    )
    html_table_formatting(header, rows, row_estimates: { 0 => data[:percentage_synthetic] } )
  end

  def simple_target_table_html
    rows = select_rows(
      %i[
        full_targets_kwh
        current_year_kwhs
        monthly_performance
      ]
    )
    html_table_formatting(header, rows, row_estimates: { 0 => data[:percentage_synthetic] } )
  end

  def first_month_html
    data[:current_year_date_ranges][0].first.strftime('%B')
  end

  def first_target_date
    data[:first_target_date]
  end

  def cumulative_target_percent
    data[:cumulative_performance].compact.last
  end

  def year_to_date_percent_absolute_html
    format_cell(:relative_percent, cumulative_target_percent.magnitude) 
  end

  def display_charts?
    data[:show_charts]
  end

  def limited_data?
    data[:limited_data]
  end

  private

  def select_rows(types)
    types = ALL_TABLE_ROWS_CONFIG.keys if types.nil?
    types.map do |type|
      config = ALL_TABLE_ROWS_CONFIG[type]
      format_row(config[:name], data[type], config[:datatype])
    end
  end

  def header
    ['Month', header_months(data[:current_year_date_ranges], data[:partial_months])].flatten
  end

  def calculate
    data # dummy call - TODO(PH, 6Jan2020) - check for failure before setting calculation_worked
    @calculation_worked = true
  end

  def data
    @data ||= calculate_data
  end

  def calculate_data
    raw = CalculateMonthlyTrackAndTraceData.new(@school, @fuel_type)
    raw.raw_data
  end

  def format_row(name, data, datatype)
    [ name, format_rows(data, datatype) ].flatten
  end

  def header_months(dates, partial_months)
    dates.map.with_index do |date_range, index|
      partial = partial_months[index] ? ' (partial)' : ''
      date_range.first.strftime('%b') + partial
    end
  end

  def format_rows(years_values, datatype = :kwh)
    years_values.map { |v| format_cell(datatype, v) }
  end

  def format_cell(datatype, value)
    FormatEnergyUnit.format(datatype, value, :html, false, true, :target) 
  end

  def html_table_formatting(header, rows, row_estimates: nil)
    HtmlTableFormattingWithHighlightedCellsEstimatedData.new(header, rows, nil, nil, nil, :target, row_estimates: row_estimates).html
  end
end
