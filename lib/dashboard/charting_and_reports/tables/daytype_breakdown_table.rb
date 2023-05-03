class DayTypeBreakDownTableDeprecated
  def initialize(school, fuel_type, time_period = { year: 0 })
    @school = school
    @fuel_type = fuel_type
    @time_period = time_period
  end

  def html
    daytype_breakdown_table
  end

  def uk_electricity_grid_carbon_intensity_kg_per_kwh
    if @fuel_type == :gas
      EnergyEquivalences::UK_ELECTRIC_GRID_CO2_KG_KWH
    else
      ScalarkWhCO2CostValues.new(@school).uk_electricity_grid_carbon_intensity_for_period_kg_per_kwh(@time_period)
    end
  end

  private

  def daytype_breakdown_table
    hash_table = raw_daytype_breakdown_table_hash
    raw_table = transform_hash_to_table(hash_table)
    header = if @time_period == :up_to_a_year
      ['Time Of Day', 'kWh', '&pound;',  'CO2 kg', 'Percent']
    else
      ['Time Of Day', 'kWh / year', '&pound; /year',  'CO2 kg /year', 'Percent']
    end
    units = [String, :kwh, :£, :co2, :percent]
    use_table_formats = [true, true, true, true, false]
    html_tbl = HtmlTableFormatting.new(header, raw_table[0..(raw_table.length - 2)], raw_table.last, units, use_table_formats)
    html_tbl.html
  end

  def raw_daytype_breakdown_table_hash
    scalar_values = ScalarkWhCO2CostValues.new(@school)
    raw_table = {}
    [[:kwh, false, :kwh], [:£, false, :£], [:co2, false, :co2], [:kwh, true, :percent]].each do |unit, percent, output_unit|
      raw_table[output_unit] =  scalar_values.day_type_breakdown(@time_period, @fuel_type, unit, false, percent)
      raw_table[output_unit]['Total'] =  raw_table[output_unit].values.sum
    end
    raw_table
  end

  def transform_hash_to_table(hash_table)
    row_names = hash_table[:kwh].keys
    table = Array.new(row_names.length){Array.new(5)}
    %i[kwh £ co2 percent].each_with_index do |unit, col_index|
      row_names.each_with_index do |row_name, row_index|
        table[row_index][0] = row_name
        table[row_index][col_index + 1] = hash_table[unit][row_name]
      end
    end

    table
  end
end