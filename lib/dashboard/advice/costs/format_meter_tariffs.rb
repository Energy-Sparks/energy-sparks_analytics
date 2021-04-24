# returns html representing tables of all meter tariffs for a school
class FormatMeterTariffs < DashboardChartAdviceBase
  class UnhandledTariffDescriptionError < StandardError; end
  class UnhandledTypeTariffDescriptionError < StandardError; end
  attr_reader :meter
  def initialize(school, meter)
    super(school, nil, nil, nil) # inherit from DashboardChartAdviceBase to get html_table functionality
    @meter = meter
  end

  def tariff_information_html
    html = meter_description_html

    tariff_info = meter.meter_tariffs.most_recent_contiguous_real_accounting_tariffs

    html += if_not_full_tariff_coverage_html(tariff_info)

    tariff_info[:tariffs].each do |tariff|
      html += tariff_description_html(tariff)
    end

    html
  end

  private

  def meter_description_html
    meter_description = %{
      <h3>
        <%= meter.fuel_type.to_s.capitalize %>
        meter
        <%= meter_identifier_type(meter.fuel_type) %>
        <%= meter.mpan_mprn %> <%= meter_name %>:
      </h3>
    }

    generate_html(meter_description, binding)
  end

  def tariff_description_html(tariff)
    table_data = single_tariff_table_html(tariff)
    tariff_description = %{
      <p>
        <%= tariff.tariff[:name] %>:
        <%= tariff_dates_html(tariff) %>
      </p>
      <p>
        <%= table_data %>
      </p>
    }

    generate_html(tariff_description, binding)
  end

  def meter_name
    meter.name.nil? || meter.name.strip.empty? ?  '' : "(#{meter.name})"
  end

  def tariff_dates_html(tariff)
    start_date_text = tariff.tariff[:start_date].strftime('%d %b %Y')

    end_date_text = if tariff.tariff[:end_date] == N3rgyTariffs::INFINITE_DATE
                      'to date'
                    else
                      tariff.tariff[:end_date].strftime('%d %b %Y')
                    end

    dates_text = %{
      <%= start_date_text %> to <%= end_date_text %>
    }
    generate_html(dates_text, binding)
  end

  def missing_tariff_information_text
    %(
      <p>
        Unfortunately, we don't have detailed meter information for this meter, so we are using defaults
        for your area. Could you <a href="mailto:hello@energysparks.uk?subject=Meter tariff information for <%= @school.name %> &">contact us</a>
        and let us know your current tariffs and we can set them up so the information on this page is accurate?
        This will also allow us to analyse your tariff to see if there are opportunities for cost reduction.
      </p>
    )
  end

  def meter_identifier_type(fuel_type)
    fuel_type == :electricity ? 'MPAN' : 'MPRN'
  end

  def rate_type_description(rate_type, costs)
    return MeterTariffs::BILL_COMPONENTS[rate_type][:summary] if MeterTariffs::BILL_COMPONENTS.key?(rate_type)
    rate_description(rate_type, costs)
  end

  def rate_description(rate_type, costs)
    case rate_type.to_s
    when 'flat_rate'
      'Flat Rate'
    when /^rate[0-9]$/
      time_range_description(costs)
    when 'daytime_rate', 'nighttime_rate'
      rate_type.to_s.humanize + ' ' + costs[:from].to_s + ' to ' + costs[:to].to_s
    else
      raise UnhandledTypeTariffDescriptionError, "Unknown type #{rate_type}"
    end
  end

  def time_range_description(costs)
    costs[:from].to_s + ' to ' + costs[:to].to_s
  end


  def tiers_description(costs)
    tiers = costs.select { |k, _v| k.to_s.match(/^tier[0-9]$/) }
    desc = costs.map { |_k, v| one_tier_description(v[:low_threshold], v[:high_threshold])}.join(',')
    '(' + desc + ')'
  end

  def one_tier_description(tier_config)
    low_threshold  = tier_config[:low_threshold]
    high_threshold = tier_config[:high_threshold]

    if high_threshold.infinite?
      "> #{low_threshold.round(0)} kwh"
    elsif low_threshold.zero?
      "< #{high_threshold.round(0)} kwh"
    else
      "#{low_threshold.round(0)} to #{high_threshold.round(0)} kwh"
    end
  end

  def tier_rate_description(costs, tier_config)
    time_range_description(costs) + ' ' + one_tier_description(tier_config)
  end

  def tier_rates_description(rate_type, costs)
    tiers = costs.select { |k, _v| k.to_s.match(/^tier[0-9]$/) }

    tiers.map do |_tier_name, tier_config|
      [
        tier_rate_description(costs, tier_config),
        FormatEnergyUnit.format(:£, tier_config[:rate], :html, false, false, :accountant) + '/kWh'
      ]
    end
  end

  def single_tariff_table_html(tariff)
    rates = tariff.tariff[:rates].map do |rate_type, costs|
      if tariff.tiered_rate_type?(rate_type)
        tier_rates_description(rate_type, costs)
      else
        [
          [
            rate_type_description(rate_type, costs),
            FormatEnergyUnit.format(:£, costs[:rate], :html, false, false, :accountant) + '/' + costs[:per].to_s
          ]
        ]
      end
    end.flatten(1)

    header = ['Tariff type', 'Rate']
    html_table(header, rates)
  end

  def tariff_description_html_no_2(tariff)
    case tariff.class.name
    when AccountingTariff
    when GenericAccountingTariff
    else
      raise UnhandledTariffDescriptionError, "Unable to display tariff of type #{tariff.class.name}"
    end
  end

  def if_not_full_tariff_coverage_html(tariff_info)
    html = ''
    contact_us_for_tariff_setup = false

    if tariff_info[:start_date] > meter.amr_data.start_date
      contact_us_for_tariff_setup = true
      html += %{
        Warning: information is only available on your tariffs
        from <%= date_html(tariff_info[:start_date]) %> but we have
        meter readings from <%= date_html(meter.amr_data.start_date) %>.
      }
    end

    if tariff_info[:end_date] < meter.amr_data.end_date
      contact_us_for_tariff_setup = true
      html += %{
        Warning: information is only available on your tariffs
        up until <%= date_html(tariff_info[:end_date]) %> but we have
        meter readings until <%= date_html(meter.amr_data.end_date) %>.
      }
    end

    if contact_us_for_tariff_setup
      html += %{
        If you would like your tariff configuration updated
        please contact Energy Sparks
        <a href="mailto:hello@energysparks.uk?subject=Setup%20accounting%20tariff%20for%20meter%20<%= meter.mpxn %>?&">hello@energysparks.uk</a>.
      }
    end

    html = "<p>" + html + "</p>" if html.length > 0

    generate_html(html, binding)
  end

  def date_html(date)
    date.strftime('%d-%m-%Y')
  end
end

# for backwards compatibility with old financial advice classes
class FormatMetersTariffs < DashboardChartAdviceBase
  def initialize(school)
    @school = school
  end

  def tariff_information_html(meter_list = nil)
    html = ''
    all_meters = meter_list.nil? ? [@school.electricity_meters, @school.heat_meters].flatten : meter_list
    all_meters.each do |meter|
      html += FormatMeterTariffs.new(@school, meter).tariff_information_html
    end
    html
  end
end
