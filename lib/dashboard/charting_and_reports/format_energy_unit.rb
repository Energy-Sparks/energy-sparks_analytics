class FormatEnergyUnit
  def self.format(unit, value)
    unit_description = {
      kwh:            'kWh',
      kw:             'kW',
      co2:            'kg CO2',
      £:              '£',
      library_books:  'library books',
      km:             'km',
      litre:          'litres',
      kg:             'kg',
      shower:         'showers',
      home:           'homes',
      kettle:         'kettles',
      ice_car:        'km',
      smartphone:     'smartphone charges',
      tree:           'trees',
      teaching_assistant: 'teaching assistant (hours)'
    }
    check_units(unit_description, unit)
    if value.nil?
      unit_description[unit]
    elsif unit == :£
      if value >= 1.0
        '£' + scale_num(value)
      else
        scale_num(value * 100.0) + 'p'
      end
    else
      "#{scale_num(value)} #{unit_description[unit]}"
    end
  end

  def self.check_units(unit_description, unit)
    unless unit_description.key?(unit)
      raise EnergySparksUnexpectedStateException.new("Unexpected unit #{unit}")
    end
  end

  def self.scale_num(number)
    if number.nil?
      '' # specific case where no value specified
          
    elsif number.magnitude == 0.0
      '0.0'  
    elsif number.magnitude < 0.01
      sprintf '%.6f', number
    elsif number.magnitude < 0
      sprintf '%.3f', number
    elsif number.magnitude < 50
      sprintf '%.2f', number
    elsif number.magnitude < 1000
      sprintf '%.0f', number
    else
      number.round(0).to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
    end
  end
end