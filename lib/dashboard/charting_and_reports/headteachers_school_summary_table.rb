class HeadTeachersSchoolSummaryTable
  attr_reader :scalar

  def initialize(school)
    @school = school
    @scalar = ScalarkWhCO2CostValues.new(@school)
  end

  def html
    HtmlTableFormatting.new(header_html, format_rows(data_by_fuel_type)).html
  end

  private

  def header_html
    [
      '',
      'Annual Use (kWh)',
      'Annual Cost (&pound;)',
      '&percnt; change from previous year',
      '&percnt; change in last 4 weeks',
      'Energy saving if you matched the most efficient_schools (&pound;)'
    ] 
  end

  def data_by_fuel_type
    @school.fuel_types(false).map do |fuel_type|
      values_for_fuel_type(fuel_type)
    end
  end

  def format_rows(rows)
    rows.map do |row|
      row.map do |_field_name, field|
        FormatEnergyUnit.format(field[:units], field[:data], :html, false, true) rescue 'error'
      end
    end
  end

  def values_for_fuel_type(fuel_type)
    last_4_week_comparison  = compare_two_periods(fuel_type, { schoolweek: -3..0 }, { schoolweek: -7..-4 })
    last_2_years_comparison = compare_two_periods(fuel_type, { year: 0 }, { year: -1 })
    difference = difference_to_exemplar_£(last_2_years_comparison[:current_£], fuel_type)

    {
      fuel_type:          { data: fuel_type.to_s.humanize.capitalize,       units: :fuel_type },
      this_year_kwh:      { data: last_2_years_comparison[:current_kwh],    units: :kwh },
      this_year_£:        { data: last_2_years_comparison[:current_£],      units: :£ },
      change_years:       { data: last_2_years_comparison[:percent_change], units: :percent },
      change_4_weeks:     { data: last_4_week_comparison[:percent_change],  units: :percent },
      examplar_benefit:   { data: difference,                               units: :£ }
    }
  end

  def difference_to_exemplar_£(actual_£, fuel_type)
    return nil if actual_£.nil?
    examplar = BenchmarkMetrics.exemplar_£(@school, fuel_type)
    [actual_£ - examplar, 0.0].max
  end

  def compare_two_periods(fuel_type, period1, period2)
    current_period_kwh  = checked_get_aggregate(period1, fuel_type, :kwh)
    current_period      = checked_get_aggregate(period1, fuel_type, :£)
    previous_period     = checked_get_aggregate(period2, fuel_type, :£)
    percent_change      = (current_period.nil? || previous_period.nil?) ? nil : (current_period - previous_period)/previous_period 
    { current_kwh: current_period_kwh, current_£: current_period, previous_£: previous_period, percent_change: percent_change }
  end

  def checked_get_aggregate(period, fuel_type, data_type)
    begin
      scalar.aggregate_value(period, fuel_type, data_type)
    rescue EnergySparksNotEnoughDataException => _e
      nil
    end
  end
end
