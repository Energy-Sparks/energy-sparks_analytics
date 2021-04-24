# Present financial cost information using real tariff data
# The presentation varies depending on what data is available
# - if more than 1 meter: presents aggregate, plus individual meter billing
# - currently can't do solar billing because of lack of tariff informations from schools; so not implemented
# - presents individual meter billing slightly different depending on availability of:
#   tariff data; > 13 months - year on year tablular and chart comparison, monthly chart
#                < 1 month - no numeric tablular information as billing always monthly, daily chart
#                1 to 13 months - monthly tabular and chart presentation, no comparison
class CostAdviceBase < AdviceBase
  def enough_data
    :enough 
  end

  def relevance
    aggregate_meter.nil? || aggregate_meter.amr_data.days < 14 ? :never_relevant : :relevant
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

  def rating;           5.0       end

  def has_structured_content?
    true
  end

  # only called when tariffs not set or not enough data
  def content(user_type: nil)
    tariffs_not_set_html
  end

  def structured_content(user_type: nil)
    content_information = []
    content_information += meter_costs if has_dcc_meters? && real_meters.length > 1
    content_information.push(introduction_to_school_finances)
    content_information
  end

  private

  def real_meters
    @school.real_meters.select { |m| m.fuel_type == fuel_type }
  end

  # TODO(PH, 9Apr2021) remove once testing complet on test
  #                    restricts meter breakdown to dcc only schools
  def has_dcc_meters?
    real_meters.any? { |m| m.dcc_meter }
  end

  def meter_costs
    show_aggregate_tariffs = real_meters.length == 1
    meter_cost_list = [ MeterCost.new(@school, aggregate_meter.original_meter, show_aggregate_tariffs, true).content ]
    real_meters.each do |meter|
      meter_cost_list.push(MeterCost.new(@school, meter.original_meter, true, false).content)
    end
    meter_cost_list
  end

  def tariffs_not_set_html
    text = %{
      <p>
        Energy Sparks can provide analysis of your billing information.
        Your tariffs are currently not set up in Energy Sparks.
        If you would like us to provide analysis of your bills online
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

  def introduction_to_school_finances
    {
      title:    'How Energy Sparks calculates energy costs',
      content:  [ { type: :html, content: INTRO_TO_SCHOOL_FINANCES_2 } ]
    }
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

  def component_pages
    [
      ElectricityCostsIntroductionAdvice,
      CostsHowEnergySparksCalculatesThem,
      # ElectricityTariffs
    ]
  end

  def aggregate_meter
    @school.aggregated_electricity_meters&.original_meter
  end

  def underlying_meters; @school.electricity_meters end
end

class AdviceGasCosts < CostAdviceBase
  def fuel_type; :gas end

  def component_pages
    [
      GasCostsIntroductionAdvice,
      CostsHowEnergySparksCalculatesThem,
      # GasTariffs
    ]
  end

  def aggregate_meter
    @school.aggregated_heat_meters&.original_meter
  end

  def underlying_meters; @school.heat_meters end
end
