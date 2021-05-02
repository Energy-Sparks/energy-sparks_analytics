# Present financial cost information using real tariff data
# The presentation varies depending on what data is available
# - if more than 1 meter: presents aggregate, plus individual meter billing
# - currently can't do solar billing because of lack of tariff informations from schools; so not implemented
# - presents individual meter billing slightly different depending on availability of:
#   tariff data; > 13 months - year on year tablular and chart comparison, monthly chart
#                < 1 month - no numeric tablular information as billing always monthly, daily chart
#                1 to 13 months - monthly tabular and chart presentation, no comparison
class CostAdviceBase < AdviceBase
  include Logging
  def enough_data
    :enough
  end

  def relevance
    aggregate_meter.nil? ? :never_relevant : :relevant
  end

  def self.template_variables
    { 'Summary' => { summary: { description: 'Financial costs', units: String } } }
  end

  def summary
    @summary ||= summary_text
  end

  def summary_text
    'Financial analysis'
  end

  def rating
    puts "Got here rating = #{calculate_rating_from_range(1.0, 0.0, average_real_tariff_coverage_percent)}"
    @rating ||= calculate_rating_from_range(1.0, 0.0, average_real_tariff_coverage_percent)
  end

  def has_structured_content?
    real_meters.length > 1
  end

  def content(user_type: nil)
    c = [
      aggregate_meter_costs[:content],
      { type: :html, content: INTRO_TO_SCHOOL_FINANCES_2 }
    ].flatten
    remove_diagnostics_from_html(c, user_type)
  end

  def structured_content(user_type: nil)
    puts "Got here 44"; rating
    
    content_information = []
    content_information += meter_costs
    content_information.push(introduction_to_school_finances)

    remove_diagnostics_from_structured_content(content_information, user_type)
  end

  private

  def real_meters
    @school.real_meters.select { |m| m.fuel_type == fuel_type }
  end

  def average_real_tariff_coverage_percent
    @average_real_tariff_coverage_percent ||= calculate_average_real_tariff_coverage
  end

  def calculate_average_real_tariff_coverage
    start_date, end_date = year_start_end_dates

    # map then sum to avoid statsample bug
    total_percent = real_meters.map do |meter|
      meter_cost(meter, true, false, start_date, end_date).percent_real
    end.sum

    total_percent / real_meters.length
  end

  def meter_costs
    meter_cost_list = [aggregate_meter_costs]

    start_date, end_date = year_start_end_dates

    # aggregate, already reported, so only report underlying meters

    if real_meters.length > 1 
      # do remaining meters
      real_meters.each do |meter|
        meter_cost_list.push(meter_cost(meter, true, false, start_date, end_date).content)
      end
    end

    meter_cost_list
  end

  def meter_cost(meter, show_tariffs, aggregated, start_date, end_date)
    MeterCost.new(@school, meter, show_tariffs, aggregated, start_date, end_date)
  end

  def aggregate_meter_costs
    show_aggregate_tariffs = real_meters.length == 1
    start_date, end_date = year_start_end_dates
    meter_cost(aggregate_meter, show_aggregate_tariffs, true, start_date, end_date).content
  end

  def introduction_to_school_finances
    {
      title:    'How Energy Sparks calculates energy costs',
      content:  [ { type: :html, content: INTRO_TO_SCHOOL_FINANCES_2 } ]
    }
  end

  def year_start_end_dates
    end_date = aggregate_meter.amr_data.end_date
    start_date = [end_date - 365 - 364, aggregate_meter.amr_data.start_date].max
    [start_date, end_date]
  end

  # COPY OF INTRO_TO_SCHOOL_FINANCES_1
  INTRO_TO_SCHOOL_FINANCES_2 = %q(
    <p>
      Energy Sparks calculates electricity and gas costs using 2 different
      methods:
    </p>
    <p>
      1. <strong>Economic Costs</strong>:
    </p>
      <ul>
        <li>
          this assumes a simple cost model, with electricity costing 12p/kWh
          and gas 3p/kWh
        </li>
        <li>
          generally, this method is used when information is presented to
          pupils because it is easy to understand, and allows them to do simple maths
          converting between kWh and &#163;
        </li>
        <li>
          we also use it for economic forecasting, when doing cost benefit
          analysis for suggested improvements to your energy management, as it better
          represents future energy prices/tariffs than your current potentially
          volatile tariffs as these can change from year to year
        </li>
      </ul>
    <p>
      2. <strong>Accounting Costs</strong>:
    </p>
        <ul>
          <li>
            These represent your real energy costs and represent all the
            different types of standing charges applied to your account
          </li>
          <li>
            To do this we need to know what these tariffs are, sometimes these
            can be provided by all schools by a local authority, and sometimes you will
            need to provide us the information is not available from the Local
            Authority. MAT or Energy Supplier
          </li>
          <li>
            We can use this more accurate tariff information to provide more
            detailed advice on potential cost savings through tariff changes or meter
            consolidation
          </li>
        </ul>
  ).freeze

=begin
  # TODO(PH, 9Apr2021) remove once testing complete on test
  #                    restricts meter breakdown to dcc only schools
  def has_dcc_meters?
    real_meters.any? { |m| m.dcc_meter }
  end

  def tariffs_not_enough_tariff_data
    text = %{
      <p>
        <% if tariff_status == :no_tariffs %>
          You currently don't have any accounting tariffs set for this meter.
        <% else %>
          You have some tariff information setup for this meter but it doesn't
          cover the <%= time_period_of_tariffs_needed %> we need to provide analysis of your bill.
        <% end %>
        If you would like us to provide a full analysis of your bills online
        please email <a href="mailto:hello@energysparks.uk?subject=Meter%20tariff%20information%20for%20<%= @school.name %>">hello@energysparks.uk</a>
        with some example bills.
        Your billing analysis will only be available to the school and not publicly displayed.
      </p>
    }
    missing_tariffs_text = ERB.new(text).result(binding)
    [
      { type: :html, content: "<h2>Analysis of #{fuel_type} costs</h2>" },
      { type: :html, content: missing_tariffs_text }
    ]
  end

  def solar_pv_not_supported
    text = %{
      <p>
        Energy Sparks currently doesn't support billing calculations
        if you have solar pv. If you think this would be a useful feature
        and would help you please email us at
        <a href="mailto:hello@energysparks.uk?subject=It%20would%20helpful%20to%20us%20if%20Energy%20Sparks%20council%20provide%20billing%20information%20for%20solar%20pv for <%= @school.name %>">hello@energysparks.uk</a>
        with some example bills.
        Your billing analysis will only be available to the school and not publicly displayed.
      </p>
    }
    [
      { type: :html, content: "<h2>Analysis of #{fuel_type} costs</h2>" },
      { type: :html, content: ERB.new(text).result(binding) }
    ]
  end

  def time_period_of_tariffs_needed
    days = [aggregate_meter.amr_data.days, 2 * 365.0].min
    FormatEnergyUnit.format(:years, days / 365.0, :html)
  end
=end
end

class AdviceElectricityCosts < CostAdviceBase
  def fuel_type; :electricity end
  def aggregate_meter; @school.aggregated_electricity_meters&.original_meter end
  def underlying_meters; @school.electricity_meters end
end

class AdviceGasCosts < CostAdviceBase
  def fuel_type; :gas end
  def aggregate_meter; @school.aggregated_heat_meters&.original_meter end
  def underlying_meters; @school.heat_meters end
end
