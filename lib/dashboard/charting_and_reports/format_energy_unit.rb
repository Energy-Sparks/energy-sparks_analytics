require 'bigdecimal'

class FormatEnergyUnit
  UNIT_DESCRIPTION_TEXT = {
    kwh:                          'kWh',
    kw:                           'kW',
    kwh_per_day:                  'kWh/day',
    kwh_per_day_per_c:            'kWh/day/C',
    co2:                          'kg CO2',
    m2:                           'm2',
    pupils:                       'pupils',
    £:                            '£',
    accounting_cost:              '£',
    days:                         'days',
    library_books:                'library books',
    km:                           'km',
    litre:                        'litres',
    kg:                           'kg',
    shower:                       'showers',
    home:                         'homes',
    homes_gas:                    'homes (gas usage)',
    homes_electricity:            'homes (electricity usage)',
    kettle:                       'kettles',
    ice_car:                      'km',
    bev_car:                      'km',
    tv:                           'tvs',
    computer_console:             'computer consoles',
    hour:                         'hours',
    smartphone:                   'smartphone charges',
    tree:                         'trees',
    percent:                      '%',
    r2:                           '',
    temperature:                  'C',
    years_range:                  'years',
    years:                        'years',
    years_decimal:                'years',
    £_range:                      '£',
    £_per_kwh:                    '£/kWh',
    kg_co2_per_kwh:               'kg CO2/kWh',
    date:                         '',
    datetime:                     '',
    gas:                          'gas',
    electricity:                  'electricity',
    teaching_assistant:           'teaching assistants',
    teaching_assistant_hours:     'teaching assistant (hours)',
    carnivore_dinner:             'dinners',
    vegetarian_dinner:            'dinners',
    onshore_wind_turbine_hours:   'onshore wind turbine hours',
    onshore_wind_turbines:        'onshore wind turbines',
    offshore_wind_turbine_hours:  'offshore wind turbine hours',
    offshore_wind_turbines:       'offshore wind turbines',
    solar_panels_in_a_year:       'solar panels in a year',
    solar_panels:                 'solar panels'
  }.freeze

  UNIT_DESCRIPTION_HTML = {
    £:              '&pound;',
    m2:             'm<sup>2</sup>',
    percent:        '&percnt;'
  }.freeze

  def self.format(unit, value, medium = :text, convert_missing_types_to_strings = false, in_table = false, user_numeric_comprehension_level = :ks2)
    return '' if value.nil? && in_table
    unit = unit.keys[0] if unit.is_a?(Hash) # if unit = {kwh: :gas} - ignore the :gas for formatting purposes
    return "#{scale_num(value, false, user_numeric_comprehension_level)}" if unit == Float
    return value.to_s if convert_missing_types_to_strings && !UNIT_DESCRIPTION_TEXT.key?(unit)
    check_units(UNIT_DESCRIPTION_TEXT, unit)
    if value.nil? && unit != :temperature
      UNIT_DESCRIPTION_TEXT[unit]
    elsif unit == :£
      format_pounds(value, medium, user_numeric_comprehension_level)
    elsif unit == :days
      format_days(value)
    elsif unit == :£_per_kwh
      format_pounds(value, medium, user_numeric_comprehension_level) + '/kWh'
    elsif unit == :r2
      sprintf('%.2f', value)
    elsif unit == :£_range
      format_pound_range(value, medium, user_numeric_comprehension_level)
    elsif unit == :temperature
      "#{value.round(1)}C"
    elsif unit == :years_range
      format_years_range(value)
    elsif unit == :years
      format_time(value)
    elsif unit == :percent
      "#{scale_num(value * 100.0, false, user_numeric_comprehension_level)}#{type_format(unit, medium)}"
    elsif unit == :date
      value.strftime('%A %e %b %Y')
    elsif unit == :datetime
      value.strftime('%A %e %b %Y %H:%M')
    else
      "#{scale_num(value, false, user_numeric_comprehension_level)}" + (in_table ? '' : " #{type_format(unit, medium)}")
    end
  end

  def self.format_pound_range(range, medium, user_numeric_comprehension_level)
    if ((range.last - range.first) / range.last).magnitude < 0.05 ||
      (range.first.magnitude < 0.005 && range.last.magnitude < 0.005)
      format_pounds(range.first, medium, user_numeric_comprehension_level)
    else
      format_pounds(range.first, medium, user_numeric_comprehension_level) + ' to ' + format_pounds(range.last, medium, user_numeric_comprehension_level)
    end
  end

  def self.format_years_range(range)
    if range.first == range.last
      format_time(range.first)
    else
      format_time(range.first) + ' to ' + format_time(range.last)
    end
  end

  def self.format_pounds(value, medium, user_numeric_comprehension_level)
    if value.magnitude >= 1.0
      # £-40.00 => -£40.00
      (value < 0.0 ? '-' : '') + type_format(:£, medium) + scale_num(value.magnitude, true, user_numeric_comprehension_level)
    else
      scale_num(value * 100.0, true, user_numeric_comprehension_level) + 'p'
    end
  end

  def self.format_time(years)
    if years < (1.0 / 365.0) && years > 0.0 # less than a day
      minutes = 24 * 60 * 365.0 * years
      if minutes < 90
        minutes.round(0).to_s + ' minute' + singular_plural(minutes)
      else
        (minutes / 60.0).round(0).to_s + ' hours'
      end
    elsif years < (3.0 / 12.0) # less than 3 months
      days = (years * 365.0).round(0)
      if days <= 14
        days.to_s + ' day' + singular_plural(days)
      else
        (days / 7.0).round(0).to_s + ' weeks'
      end
    elsif years <= 1.51
      months = months_from_years(years)
      months.to_s + ' month' + singular_plural(months)
    elsif years < 5.0
      y = years.floor
      years_str = sprintf('%.0f ', y) + 'year' + singular_plural(y)
      months = months_from_years(years - y)
      years_str + ' ' + months.to_s + ' month' + singular_plural(months)
    else
      sprintf('%.0f ', years) + 'year' + singular_plural(years)
    end
  end

  def self.months_from_years(years)
    (years * 12.0).round(0)
  end

  private_class_method def self.format_days(days)
    sprintf('%d', days.to_i) + ' day' + singular_plural(days)
  end

  def self.singular_plural(value)
    value == 1.0 ? '' : 's'
  end

  def self.type_format(unit, medium)
    if medium == :html && UNIT_DESCRIPTION_HTML.key?(unit)
      UNIT_DESCRIPTION_HTML[unit]
    else
      UNIT_DESCRIPTION_TEXT[unit]
    end
  end

  def self.check_units(unit_description, unit)
    unless unit_description.key?(unit)
      raise EnergySparksUnexpectedStateException.new("Unexpected unit #{unit}")
    end
  end

  def self.scale_num(value, in_pounds = false, user_numeric_comprehension_level = :ks2)
    number = significant_figures_user_type(value, user_numeric_comprehension_level)
    return 0.to_s if number.zero?
    before_decimal_point = number.to_s.gsub(/^(.*)\..*$/, '\1')
    # for some reason a number without dp e.g. 15042 when mathed with gsub(/.*(\..*)/, '\1') returns 15042 and not null as it should match ./?
    after_decimal_point = number.to_s.include?('.') ? number.to_s.gsub(/.*(\..*)/, '\1').gsub(/^.*\.0$/, '') : ''
    if in_pounds && !after_decimal_point.empty? && after_decimal_point.length < 3
      # add zero pence onto e.g. £23.1 so it becomes £23.10
      after_decimal_point += '0'
    elsif number.magnitude >= 1000
      return number.round(0).to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse + after_decimal_point
    end
    before_decimal_point + after_decimal_point
  end

  private_class_method def self.user_numeric_comprehension_level(user_type)
    case user_type
      # :no_decimals and :to_pence are also valid, but dealt with outwith the significant figures handling
    when :ks2
      2
    when :approx_accountant
      4
    when :accountant, :energy_expert
      10
    else
      raise EnergySparksUnexpectedStateException.new('Unexpected nil user_type for user_numeric_comprehension_level') if user_type.nil?
      raise EnergySparksUnexpectedStateException.new("Unexpected nil user_type #{user_type}for user_numeric_comprehension_level") if user_type.nil?
    end
  end

  def self.significant_figures_user_type(value, user_numeric_comprehension_level)
    return value.round(0) if user_numeric_comprehension_level == :no_decimals
    return value.round(2) if user_numeric_comprehension_level == :to_pence
    significant_figures(value, user_numeric_comprehension_level(user_numeric_comprehension_level))
  end

  def self.significant_figures(value, significant_figures)
    return 0 if value.nil? || value.zero?
    BigDecimal(value, significant_figures).to_f # value.round(-(Math.log10(value).ceil - significant_figures))
  end
end



# eventually migrate from FormatEnergyUnit to more generic FormatUnit
class FormatUnit < FormatEnergyUnit
end
