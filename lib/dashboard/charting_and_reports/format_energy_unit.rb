
class FormatEnergyUnit
  UNIT_DESCRIPTION_TEXT = {
    kwh:                'kWh',
    kw:                 'kW',
    kwh_per_day:        'kWh/day',
    kwh_per_day_per_c:  'kWh/day/C',
    co2:                'kg CO2',
    m2:                 'm2',
    pupils:             'pupils',
    £:                  '£',
    accounting_cost:    '£',
    days:               'days',
    library_books:      'library books',
    km:                 'km',
    litre:              'litres',
    kg:                 'kg',
    shower:             'showers',
    home:               'homes',
    kettle:             'kettles',
    ice_car:            'km',
    smartphone:         'smartphone charges',
    tree:               'trees',
    percent:            '%',
    temperature:        'C',
    years_range:        'years',
    £_range:            '£',
    £_per_kwh:          '£/kWh',
    date:               '',
    teaching_assistant: 'teaching assistant (hours)'
  }.freeze

  UNIT_DESCRIPTION_HTML = {
    £:              '&pound;',
    m2:             'm<sup>2</sup>',
    percent:        '&percnt;'
  }.freeze

  def self.format(unit, value, medium = :text, convert_missing_types_to_strings = false, in_table = false)
    unit = unit.keys[0] if unit.is_a?(Hash) # if unit = {kwh: :gas} - ignore the :gas for formatting purposes
    return "#{scale_num(value)}" if unit == Float
    return value.to_s if convert_missing_types_to_strings && !UNIT_DESCRIPTION_TEXT.key?(unit)

    check_units(UNIT_DESCRIPTION_TEXT, unit)
    if value.nil? && unit != :temperature
      UNIT_DESCRIPTION_TEXT[unit]
    elsif unit == :£
      format_pounds(value, medium)
    elsif unit == :£_per_kwh
      format_pounds(value, medium) + '/kWh'
    elsif unit == :£_range
      format_pound_range(value, medium)
    elsif unit == :temperature
      "#{scale_num(value)}C"
    elsif unit == :years_range
      format_years_range(value)
    elsif unit == :percent
      "#{scale_num(value * 100.0)}#{type_format(unit, medium)}"
    elsif unit == :date
      value.strftime('%A %e %b %Y')
    else
      "#{scale_num(value)}" + (in_table ? '' : " #{type_format(unit, medium)}")
    end
  end

  def self.format_pound_range(range, medium)
    if ((range.last - range.first) / range.last).magnitude < 0.05 ||
      (range.first.magnitude < 0.005 && range.last.magnitude < 0.005)
      format_pounds(range.first, medium)
    else
      format_pounds(range.first, medium) + ' to ' + format_pounds(range.last, medium)
    end
  end

  def self.format_years_range(range)
    if range.first == range.last
      format_time(range.first)
    else
      format_time(range.first) + ' to ' + format_time(range.last)
    end
  end

  def self.format_pounds(value, medium)
    if value.magnitude >= 1.0
      type_format(:£, medium) + scale_num(value, true)
    else
      scale_num(value * 100.0) + 'p'
    end
  end

  def self.format_time(years)
    if years < (1.0 / 12.0)
      days = (years / 365.0).round(0)
      days.to_s + ' day' + singular_plural(days)
    elsif years < 1.0
      months = (years / 12.0).round(0)
      months.to_s + ' month' + singular_plural(months)
    else
      sprintf('%.1f', years) + 'year' + singular_plural(years)
    end
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

  def self.scale_num(number, in_pounds = false)
    if number.nil?
      '' # specific case where no value specified
    elsif number.magnitude == 0.0
      '0.0'  
    elsif number.magnitude < 0.01
      sprintf '%.6f', number
    elsif number.magnitude < 0
      sprintf '%.3f', number
    elsif number.magnitude < 50
      if in_pounds
        sprintf '%.2f', number
      else
        sprintf '%.1f', number
      end
    elsif number.magnitude < 1000
      sprintf '%.0f', number
    else
      number.round(0).to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
    end
  end
end

# eventually migrate from FormatEnergyUnit to more generic FormatUnit
class FormatUnit < FormatEnergyUnit
end
