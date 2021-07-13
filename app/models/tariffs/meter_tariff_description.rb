class MeterTariffDescription
  def self.description_html(school, meter, attribute_type)
    case attribute_type
    when /^\d\d:\d\d to \d\d:\d\d$/
      rate(attribute_type)
    when /^Duos.*$/
      duos(attribute_type, school, meter)
    when /^Climate.*$/
      'Climate change levy - reflecting your carbon emissions'
    else
      nil
    end
  end

  private

  private_class_method def self.real_meter_example(school, meter)
    if meter.fuel_type == :electricity && school.electricity_meters.length > 1
      school.electricity_meters[0]
    elsif meter.fuel_type == :gas && school.heat_meters.length > 1
      school.heat_meters[0]
    else
      meter
    end
  end

  private_class_method def self.rate(attribute_type)
    text = %( 
      This is the charge for electricity consumed
      from <%= attribute_type %> per kWh.
    )
    ERB.new(text).result(binding)
  end

  private_class_method def self.duos(attribute_type, school, meter)
    duos_introduction_html +
    duos_regional_charge_table_html(school, meter) +
    duos_addedum_html
  end

  private_class_method def self.duos_introduction_html
    %(
      <p>
        Duos stands for ‘Distribution use of system charges’ which is a charge
        for your school’s usage of the local distribution network (cables running
        from power stations via the national grid to your school) per kWh of
        electricity you consume. The charging increases during peak periods to reflect
        the cost of providing enough cable capacity when demand is highest.
        Duos Red represents the period of the week of peak capacity
        and has the highest charge. Duos Green are the periods of lowest demand
        and amber is in between. The times of the red, amber and green periods vary
        between different regions of the UK. The periods for your region are:
      </p>
    )
  end

  private_class_method def self.duos_regional_charge_table_html(school, meter)
    real_meter = real_meter_example(school, meter)
    data = DUOSCharges.regional_charge_table(real_meter.mpxn)
    bands = data[:bands]

    header =    [ 'Region',    'Band', 'Weekdays',               'Weekends' ]
    red_row   = [ data[:name], 'red',   bands[:red][:weekdays],   bands[:red][:weekends]   ]
    amber_row = [ '',          'amber', bands[:amber][:weekdays], bands[:amber][:weekends] ]
    green_row = [ '',          'green', bands[:green][:weekdays], bands[:green][:weekends] ]

    table = %(
      <table>
        <tr><th><%= header[0]%></th><th><%= header[1]%></th><th><%= header[2]%></th></tr>
        <tr><td rowspan="5"><%= red_row[0]%></td><td><%= red_row[1]%></td><td><%= red_row[2]%></td></tr>
        <tr><td ><%= amber_row[0]%></td><td><%= amber_row[1]%></td><td><%= amber_row[2]%></td></tr>
        <tr><td ><%= green_row[0]%></td><td><%= green_row[1]%></td><td><%= green_row[2]%></td></tr>
      </table>
    )
    ERB.new(table).result(binding)
  end

  private_class_method def self.duos_addedum_html
    %(
      <p>
        If you want to reduce your duos costs then given peak costs
        are generally between 4:00pm and 7:00pm each day try to get staff
        to turn everything off - PCs and lights as soon as they finish using
        them at the end of the school day rather than leaving them for cleaning staff
        and others to turn off.
      </p>
      <p>
        Duos charges are due to be replaced by a fixed charge (per day)
        for your school in April 2022. A more technical explanation is available
        <a href="https://www.catalyst-commercial.co.uk/dcp228-duos-charges/"  target ="_blank">here</a>.
      </p>
    )
  end
end
