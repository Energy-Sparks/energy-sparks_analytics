class HotWaterTableFormatting
  def initialize(hotwater_data)
    @hotwater_data = hotwater_data
  end

  def full_analysis_table(medium = :text)
    header = [
      'Choice',
      'Annual kWh',
      'Annual ' + formatted_pound(medium),
      'Annual CO2/kg',
      'Saving ' + formatted_pound(medium),
      'Saving ' + formatted_pound(medium) + ' percent',
      'Saving CO2',
      'Saving CO2 percent',
      'Capital Cost ' + formatted_pound(medium),
      'Payback (years)'
    ]
    rows = [
      full_analysis_row('Current setup', @hotwater_data[:existing_gas], medium),
      full_analysis_row('Current setup (better boiler control)', @hotwater_data[:gas_better_control], medium),
      full_analysis_row('Point of use electric heaters', @hotwater_data[:point_of_use_electric], medium)
    ]
    HtmlTableFormatting.new(header, rows).html
  end

  private def formatted_pound(medium)
    case medium
    when :html
      '&pound;'
    when :test
      '£'
    else
      '£'
    end
  end

  private def full_analysis_row(name, row_data, medium)
    [
      name,
      format(:kwh,            row_data[:kwh],                medium),
      format(:£,              row_data[:£],                  medium),
      format(:co2,            row_data[:co2],                medium),
      format(:£,              row_data[:saving_£],           medium),
      format(:percent,        row_data[:saving_£_percent],   medium),
      format(:co2,            row_data[:saving_co2],         medium),
      format(:percent,        row_data[:saving_co2_percent], medium),
      format(:£,              row_data[:capex],              medium),
      format(:years_decimal,  row_data[:payback_years],      medium),
    ]
  end

  private def format(unit, value, medium, comprehension = :ks2)
    return '' if value.nil?
    medium.nil? ? value : FormatEnergyUnit.format(unit, value, medium, false, true, comprehension)
  end
end
