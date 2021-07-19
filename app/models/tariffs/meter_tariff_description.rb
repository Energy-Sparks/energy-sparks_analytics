class MeterTariffDescription
  include Logging
  class UnknownDuosBand < StandardError; end

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

  def self.short_description_html(school, meter, attribute_type, in_tooltip: true)
    desc = short_description(school, meter, attribute_type)

    return attribute_type if !in_tooltip || desc.nil?

    info_button(attribute_type, desc)
  end

  private

  private_class_method def self.short_description(school, meter, attribute_type)
    case attribute_type
    when /^\d\d:\d\d to \d\d:\d\d$/
      rate(attribute_type)
    when /^Flat.*$/
      'The charge per kWh of consumption for the whole day'
    when /^Duos.*$/
      duos_succinct_description(attribute_type, school, meter)
    when /^Tnuos.*$/
      %q(
        Transmission Network Use Of System Charge: based on the schools peak consumption on
        winter weekdays between 17:00 and 19:30 - to reduce make sure as many appliances
        as possible are turned off during the winter when the school closes for the day.
      )
    when /^Agreed availability.*$/
      %q(
        A charge for the cabling to provide an agreed maximum amount of power in KVA
        of electricity to the school. This can often be reduced via discussions with
        your energy supplier.
      )
    when /^Excess availability.*$/
      %q(
        A 'fine' for going over your 'Agreed Availability Limit' in a month.
        If you are being 'fined' for more than a few months a year its generally
        cheaper to ask your energy supplier to increase your 'Agreed Availability Limit'.
      )
    when /^Feed in tariff levy.*$/
      %q(
        A fee to cover the costs of supporting renewables on the electricity network.
        You can reduce this by reducing your energy consumption.
      )
    when /^Standing charge.*$/, /^Standing Charge.*$/, /^Fixed charge.*$/
      'Fixed fee for your energy supply.'
    when /^Site fee.*$/, /^Site Fee.*$/
      'Miscellaneous fixed fee.'
    when /^Settlement agency fee.*$/, /^Settlement Agency Fee.*$/
      'A fee to pay for the cost of maintaining and reading your meter'
    when /^Reactive power charge.*$/, /^Reactive Power Charge.*$/
      %q(
        A charge based on how out of balance the voltage and current consumption of your school is.
        If it is a large cost then its possible to rebalance your school but your will need an electrician
        to help you. Energy Sparks can't calculate this because we currently don't have access to
        the raw data to calculate this, so you will need to look at your paper bills; the cost
        for most schools is less than £20 per month.
      )
    when /^Data collection.*$/, /^Nhh automatic meter reading.*$/,  /^Nhh metering agent charge.*$/
      %q(
        The cost of collecting your half hourly meter readings twice a day.
        Energy Sparks uses this half hourly data to analyse your energy consumption.
      )
    when /^Meter asset provider charge.*$/
      %q(
        The cost of a third party maintaining your meter.
      )
    when /^Climate.*$/
      'Climate Change Levy: based on your carbon emissions (per kWh of consumption).
      If you reduce your consumption your CCL will reduce.'
    when /^Month$/, /^Vat.*$/, /^Variance versus last year$/, /^Total$/, /^Cost per kWh$/
      nil # no tooltip
    else
      Logging.logger.info "Missing billing tooltip description #{attribute_type}"
      nil
    end
  end

  private_class_method def self.info_button(text, tooltip)
    html = %(
      <%= text %> <i class="fas fa-info-circle" data-toggle="tooltip" data-placement="top" title="<%= tooltip %>"></i>
    )
    ERB.new(html).result(binding)
  end

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
      between <%= include_end_of_bucket_time(attribute_type) %> per kWh.
    )
    ERB.new(text).result(binding)
  end

  # not ideal having to reverse engineer the key
  # the bucket times represent the start of the bucket
  # so 23:30 to 23:30 is really 23:30 to 24:00
  def self.include_end_of_bucket_time(differential_tariff_range_str)
    t1_str, t2_str = differential_tariff_range_str.split(' to ')
    t2 = TimeOfDay.parse(t2_str)
    t2_end = TimeOfDay.add_hours_and_minutes(t2, 0, 30)
    "#{t1_str} and #{t2_end}"
  end

  private_class_method def self.duos(attribute_type, school, meter)
    duos_introduction_html +
    duos_regional_charge_table_html(school, meter) +
    duos_addedum_html
  end

  private_class_method def self.duos_succinct_description(attribute_type, school, meter)
    charge_times = duos_regional_charge_summary_times(school, meter, attribute_type)
    "Distributed use of system charge: - charge per kWh of usage during these times:  #{charge_times}. To reduce, reduce the schools usage during these times"
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

  private_class_method def self.duos_regional_charge_summary_times(school, meter, attribute_type)
    real_meter = real_meter_example(school, meter)
    data = DUOSCharges.regional_charge_table(real_meter.mpxn)
    band = duos_band(attribute_type)
    band_data = data[:bands][band]
    text = ''
    text += "weekdays: #{band_data[:weekdays]}" unless band_data[:weekdays].nil?
    text += "weekends: #{band_data[:weekends]}" unless band_data[:weekends].nil?
    text
  end

  private_class_method def self.duos_band(attribute_type)
    case attribute_type
    when /^.*green.*$/
      :green
    when /^.*amber.*$/
      :amber
    when /^.*red.*$/
      :red
    else
       raise UnknownDuosBand, "Band #{attribute_type} colour incorrect"
    end
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
