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
    puts "Got here aggregate"
    show_aggregate_tariffs = real_meters.length == 1
    meter_cost_list = [ MeterCost.new(@school, aggregate_meter.original_meter, show_aggregate_tariffs, true).content ]
    puts "Got here - the rest"
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

class CostsIntroductionAdvice < CostAdviceBase
  def initialize(school)
    super(school)
    @summary = "Your School\'s #{fuel_type.to_s.capitalize} Costs" 
    @content_data = [
      { type: :text, advice_class: advice_class, data: "<h2>#{@summary}</h2>"},
      { type: :text, advice_class: advice_class, data: availability_of_meter_tariffs_text },
      { type: :text, advice_class: advice_class, data: "<p><b>Comparison of last 2 years #{fuel_type.to_s.capitalize} costs</b></p>" },
      { type: :chart_and_text, data: chart_2_year_comparison },
      { type: :chart_and_text, data: chart_1_year_breakdown, components: [true, false, false] },
      { type: :text, advice_class: advice_class, data: "<p><b>Your last year\'s #{fuel_type.capitalize} bill components</b></p>" },
      { type: :text, advice_class: advice_class, data: "<p>Last year's bill components were as follows: </p>" },
      { type: :chart_and_text, data: chart_1_year_breakdown, components: [false, true, true] }
    ]
  end

  def advice_class
    AdviceElectricityCosts
  end

  def availability_of_meter_tariffs_text
    text = if rating == 10.0
      %q(
        <p>
          The information below provides a good estimate of your annual
          <%=  fuel_type %> costs based on meter tariff information which
          has been provided to Energy Sparks.
        </p>
      )
    elsif rating == 0.0
      %q(
        <p>
          The information below is approximate as we don't have your meter tariffs
          so are using average tariffs for your area. If you would like this web page
          to provide accurate information please provide us with your
          meter tariffs <%= email_us_html(@email_subject, 'via email') %> and we
          can help setup the tariffs so you get accurate information on this page.
        </p>
      )
    else
      %q(
        <p>
          The information below is approximate as we don't have all your meter tariff information.
          We are using a mix of your actual tariffs and some average tariffs for your
          area. If you would like this web page
          to provide accurate information please <%= email_us_html('Meter tariff information for my school', 'get in contact') %> 
          and we can help setup the remaining tariffs.
        </p>
      )
    end
  end
end


class CostsHowEnergySparksCalculatesThem < CostAdviceBase
  def initialize(school)
    super(school)
    @summary = 'How Energy Sparks calculates energy costs'
    @content_data = [
      { type: :text, advice_class: self.class, data: "<p><b>How Energy Sparks calculates costs</b></p>" },
      { type: :text, advice_class: DashboardEnergyAdvice::FinancialAdviceBase, data: DashboardEnergyAdvice::FinancialAdviceBase::INTRO_TO_SCHOOL_FINANCES_1 },
    ]
  end
end

class MeterTariffInfo < CostAdviceBase
  def initialize(school)
    super(school)
    @summary = "Your meter #{fuel_type.to_s.capitalize} Tariffs"
    tariff_table = FormatMetersTariffs.new(@school).tariff_information_html(meters)
    @content_data = [
      { type: :text, advice_class: self.class, data: tariff_table },
    ]
  end
  def rating
    @rating ||= 100.0 * MeterTariffs.accounting_tariff_availability_coverage(aggregate_meter.amr_data.start_date, aggregate_meter.amr_data.end_date, underlying_meters)
  end
end

class ElectricityTariffs < MeterTariffInfo
  def meters; @school.electricity_meters end
  def fuel_type; :electricity end
end

class AdviceFuelTypeBase < AdviceStructuredOldToNewConversion
  def initialize(school)
    super(school)
    @summary = fuel_type.to_s.capitalize + ' Costs'
  end
  def relevance
    return :never_relevant if aggregate_meter.nil?
    tariffs = MeterTariffs.accounting_tariffs_available_for_period?(aggregate_meter.amr_data.start_date, aggregate_meter.amr_data.end_date, underlying_meters)
    tariffs ? :relevant : :never_relevant
  end
  # overwrite structured content old to new converter
  # so can do per meter analysis
  def structured_content(user_type: nil)
    content_information = []
    component_pages.each do |component_page_class|
      component_page = component_page_class.new(@school)
      content_information.push(
        {
          title:    component_page.summary,
          content:  component_page.content
        }
      ) if component_page.relevance == :relevant
    end
    content_information += meter_costs if has_dcc_meters? && real_meters.length > 1
    content_information
  end
  def advice_class; self.class end
  def has_structured_content?; true end

  def meter_costs
    real_meters.map do |meter|
      MeterCost.new(@school, meter.original_meter).content
    end
  end

  def type_of_content
    content_types = []
  end

  def real_meters
    @school.real_meters.select { |m| m.fuel_type == fuel_type }
  end

  # TODO(PH, 9Apr2021) remove once testing complet on test
  #                    restricts meter breakdown to dcc only schools
  def has_dcc_meters?
    real_meters.any? { |m| m.dcc_meter }
  end
end

class ElectricityCostsIntroductionAdvice < CostsIntroductionAdvice
  def fuel_type; :electricity end
  def chart_2_year_comparison; :electricity_cost_comparison_last_2_years_accounting end
  def chart_1_year_breakdown; :electricity_cost_1_year_accounting_breakdown end
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

class GasTariffs < MeterTariffInfo
  def meters; @school.heat_meters end
  def fuel_type; :gas end
end

class GasCostsIntroductionAdvice < CostsIntroductionAdvice
  def fuel_type; :gas end
  def chart_2_year_comparison; :gas_cost_comparison_last_2_years_accounting end
  def chart_1_year_breakdown; :gas_cost_1_year_accounting_breakdown end
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
