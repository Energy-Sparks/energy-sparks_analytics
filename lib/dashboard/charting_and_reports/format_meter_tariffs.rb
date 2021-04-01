
require_relative 'dashboard_analysis_advice'

# returns html representing tables of all meter tariffs for a school
class FormatMeterTariffs < DashboardChartAdviceBase
  class UnhandledTariffDescriptionError < StandardError; end
  class UnhandledTypeTariffDescriptionError < StandardError; end
  def initialize(school)
    super(school, nil, nil, nil) # inherit from DashboardChartAdviceBase to get html_table functionality
  end

  def tariff_tables_html(meter_list = nil)
    html = ''
    all_meters = meter_list.nil? ? [@school.electricity_meters, @school.heat_meters].flatten : meter_list
    all_meters.each do |meter|
      html += tariff_table_for_meter_html(meter)
    end
    html
  end

  def tariff_table_for_meter_html(meter)
    html = ''
    html += meter_description_html(meter)
    meter.meter_tariffs.accounting_tariffs.each do |tariff|
      html += tariff_description_html(tariff)
    end
    html
  end

  private

  def meter_description_html(meter)
    meter_description = %{
      <h3>
        <%= meter.fuel_type.to_s.capitalize %>
        meter
        <%= meter_identifier_type(meter.fuel_type) %>
        <%= meter.mpan_mprn %> <%= meter_name(meter) %>:
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

  def meter_name(meter)
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
    when /rate[0-9]/
      costs[:from].to_s + ' to ' + costs[:to].to_s
    when 'daytime_rate', 'nighttime_rate'
      rate_type.to_s.humanize + ' ' + costs[:from].to_s + ' to ' + costs[:to].to_s
    else
      raise UnhandledTypeTariffDescriptionError, "Unknown type #{rate_type}"
    end
  end

  def single_tariff_table_html(tariff)
    rates = tariff.tariff[:rates].map do |rate_type, costs|
      [
        rate_type_description(rate_type, costs),
        FormatEnergyUnit.format(:£, costs[:rate], :html, false, false, :accountant) + '/' + costs[:per].to_s
      ]
    end
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
end
