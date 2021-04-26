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
    full_tariff_coverage? ? 10.0 : 0.0
  end

  def has_structured_content?
    full_tariff_coverage?
  end

  # only called when tariffs not set or not enough data
  def content(user_type: nil)
    tariffs_not_set_html
  end

  def structured_content(user_type: nil)
    content_information = []
    content_information += meter_costs
    content_information.push(introduction_to_school_finances)
    content_information
  end

  private

  # TODO (PH, 25Apr2021) this needs removing once the front end
  # per meter charting is working
  def only_breakdown_for_dcc_meters?
    has_dcc_meters? && real_meters.length > 1
  end

  def full_tariff_coverage?
    logger.info "Tariff meter overall coverage: #{tariff_status}"
    tariff_status == :full_tariff_coverage
  end

  def tariff_status
    return :solar_pv if @school.solar_pv_panels?

    kwh_start_date, kwh_end_date = year_start_end_dates
    tariff_date_range = last_contiguous_range_of_tariffs_in_date_range(kwh_start_date, kwh_end_date)

    logger.info "Combined meters tariff date range: #{tariff_date_range}"
    
    if tariff_date_range.nil?
      :no_tariffs
    else
      if kwh_start_date >= tariff_date_range.first && kwh_end_date <= tariff_date_range.last
        :full_tariff_coverage
      else
        :partial_tariff_coverage
      end
    end
  end

  # inefficient: but simplest way of determining tariff
  # availability for aggregate meter with potentially a
  # large number of underlying meters with or without tariffs
  # while staying within meter aggregation rules (e.g. deprecated meters)
  def last_contiguous_range_of_tariffs_in_date_range(start_date, end_date)
    logger.info "Checking for availability of contiguous tariffs between #{start_date} and #{end_date}?"

    valid_costs = (start_date..end_date).map do |date|
      {
        date:   date,
        exists: aggregate_meter.amr_data.date_exists_by_type?(date, :accounting_cost)
      }
    end

    grouped_valid_costs = valid_costs.slice_when do |curr, prev|
      curr[:exists] != prev[:exists]
    end.to_a

    non_nil_costs = grouped_valid_costs.select { |cost_group| cost_group.first[:exists] }
    return nil if non_nil_costs.empty?

    last_range = non_nil_costs.last
    logger.info "Contiguous date range: #{last_range.first[:date]..last_range.last[:date]}"
    last_range.first[:date]..last_range.last[:date]
  end

  def real_meters
    @school.real_meters.select { |m| m.fuel_type == fuel_type }
  end

  # TODO(PH, 9Apr2021) remove once testing complete on test
  #                    restricts meter breakdown to dcc only schools
  def has_dcc_meters?
    real_meters.any? { |m| m.dcc_meter }
  end

  def meter_costs
    meter_cost_list = [aggregate_meter_costs]
    
    if only_breakdown_for_dcc_meters?
      start_date, end_date = year_start_end_dates

      # do remaining meters
      real_meters.each do |meter|
        meter_cost_list.push(MeterCost.new(@school, meter.original_meter, true, false, start_date, end_date).content)
      end
    end
    meter_cost_list
  end

  def aggregate_meter_costs
    show_aggregate_tariffs = real_meters.length == 1
    start_date, end_date = year_start_end_dates
    MeterCost.new(@school, aggregate_meter, show_aggregate_tariffs, true, start_date, end_date).content
  end

  def tariffs_not_set_html
    tariff_status == :solar_pv ? solar_pv_not_supported : tariffs_not_enough_tariff_data
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
