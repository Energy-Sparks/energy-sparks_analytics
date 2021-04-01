require 'erb'
require_relative 'dashboard_analysis_advice'

# returns html representing tables of all meter tariffs for a school
class FormatMeterTariffs < DashboardChartAdviceBase
  def initialize(school)
    super(school, nil, nil, nil) # inherit from DashboardChartAdviceBase to get html_table functionality
  end

  def tariff_tables_html(meter_list = nil)
    tables = ''
    all_meters = meter_list.nil? ? [@school.electricity_meters, @school.heat_meters].flatten : meter_list
    all_meters.each do |meter|
      name = meter.name.nil? || meter.name.strip.empty? ?  '' : "(#{meter.name})"
      tariff_name, table_data, real_tariff = single_tariff_table_html(meter)
      table = %{
        <h3>
          <%= meter.fuel_type.to_s.capitalize %>
          meter
          <%= meter_identifier_type(meter.fuel_type) %>
          <%= meter.mpan_mprn %> <%= name %>:
        </h3>
        <p>
          <%= tariff_name %>
        </p>
        <p>
          <%= table_data %>
        </p>
      }

      table += missing_tariff_information_text unless real_tariff

      tables += generate_html(table, binding)
    end
    tables
  end

  private def missing_tariff_information_text
    %(
      <p>
        Unfortunately, we don't have detailed meter information for this meter, so we are using defaults
        for your area. Could you <a href="mailto:hello@energysparks.uk?subject=Meter tariff information for <%= @school.name %> &">contact us</a>
        and let us know your current tariffs and we can set them up so the information on this page is accurate?
        This will also allow us to analyse your tariff to see if there are opportunities for cost reduction.
      </p>
    )
  end

  private def meter_identifier_type(fuel_type)
    fuel_type == :electricity ? 'MPAN' : 'MPRN'
  end

  private def rate_type_description(rate_type)
    return MeterTariffs::BILL_COMPONENTS[rate_type][:summary] if MeterTariffs::BILL_COMPONENTS.key?(rate_type)
    rate_type.to_s.humanize
  end

  private def single_tariff_table_html(meter)
    real_tariff, tariff = find_tariff(meter)
    rates = []
    tariff[:rates].each do |rate_type, costs|
      rates.push(
        [
          rate_type_description(rate_type),
          FormatEnergyUnit.format(:£, costs[:rate], :html, false, false, :accountant) + '/' + costs[:per].to_s
        ]
      )
    end
    header = ['Tariff type', 'Rate']
    table = html_table(header, rates)
    [tariff[:name], table, real_tariff]
  end

  # returns true if have real accounting tariff, or false if only general tariff for area
  private def find_tariff(meter)
    date = meter.dcc_meter ? Date.new(2013,1,1) : Date.today
    puts "Got here fixup for old dcc tariff data" if meter.dcc_meter
    tariff = meter.meter_tariffs.accounting_tariff_for_date(date)&.tariff
puts "Got here #{date}"
ap tariff
    [!tariff[:default], tariff]
  end
end
