class AdviceSolarPV < AdviceElectricityBase
  attr_reader :summary
  def relevance
    @school.aggregated_electricity_meters.nil? ? :never_relevant : :relevant
  end

  def enough_data
    @school.solar_pv_panels? ? :enough : pv_benefit_estimator.enough_data
  end

  def pv_benefit_estimator
    @pv_benefit_alert ||= calculate_benefit
  end

  def self.template_variables
    { 'Summary' => { summary: { description: 'benefit of existing or potential pv summary', units: String } } }
  end

  def raw_content(user_type: nil)
    @school.solar_pv_panels? ? super : solar_pv_benefit_content
  end

  def summary
    @summary = @school.solar_pv_panels? ? summarise_existing_panels_benefit : summarise_potential_benefits
  end

  def solar_pv_benefit_content
    charts_and_html = []
    charts_and_html.push( { type: :html, content: '<h2>Benefits of installing solar PV</h2>' } )
    charts_and_html += debug_content
    charts_and_html.push( { type: :html, content: introduction } )
    charts_and_html.push( { type: :html, content: table_intro } )
    #charts_and_html.push( { type: :html, content: pv_benefit_estimator.solar_pv_scenario_table_html } )
    charts_and_html.push( { type: :html, content: table_explanation } )
    charts_and_html.push( { type: :html, content: caveats } )
    charts_and_html
  end

  def summarise_existing_panels_benefit
    saving = FormatEnergyUnit.format(:percent, calculate_existing_pv_panel_benefit, :text)
    "Reduced your mains electricity consumption by #{saving} last year"
  end

  def summarise_potential_benefits
    # not ideal, fishing out a numbered column from a table
    min_saving = FormatEnergyUnit.format(:percent, pv_benefit_estimator.solar_pv_scenario_table.first[6], :text)
    max_saving = FormatEnergyUnit.format(:percent, pv_benefit_estimator.solar_pv_scenario_table.last[6],  :text)
    "Installing solar pv would save up to #{max_saving} of your electricity consumption "
  end

  def rating
    5.0
  end

  private

  def calculate_benefit
    calced_benefit = AlertSolarPVBenefitEstimator.new(@school)
    calced_benefit.analyse(@school.aggregated_electricity_meters.amr_data.end_date)
    calced_benefit
  end

  def calculate_existing_pv_panel_benefit
    solar_pv_profit_loss = SolarPVProfitLoss.new(@school)
    solar_pv_profit_loss.annual_saving_from_solar_pv_percent
  end

  def introduction
    %{
      <p>
        Installing solar pv at your school will reduce the electricity you consume from the national grid,
        and reduce your school&apos;s carbon emissions. It should be seen as an addition to reducing
        your school&apos;s electricity consumption through energy efficiency rather than an alternative.
        Economically, following the removal of subsidies from solar panels it might take
        between 2 and 15 years to payback the capital costs of installing solar panels
        depending on your assumptions for future electricity tariffs, but
        PTAs will often be prepared to raise some of the capital costs making
        it more economic for schools.
      <p>
    }
  end

  def table_intro
    %{
      <p>
        The table below provides estimates of the potential benefits and costs of
        installing different quantities of solar pv panels at your school:
      <p>
    }
  end

  def table_explanation
    text = %{
      <p>
        The table contains a range of capacities, calculated using half hourly electricity
        meter data from your school and real solar pv data for your locality for the last year
        to produce a reasonable estimate of the potential for solar pv to reduce your
        main consumption. Energy Sparks has estimated that installing
        <%= FormatEnergyUnit.format(:kwp, pv_benefit_estimator.optimum_kwp, :html) %> provides the
        best payback. However, installing slightly more or less than the best payback
        makes little difference to the economics.
      <p>
    }
    ERB.new(text).result(binding)
  end

  def caveats
    text = %{
      <p>Comments</p>
      <ul>
        <li>
          The calculations currently assume you will get some income from any
          exported electricity. Since the end of the Feed-In-Tariff in April 2019
          automatic income from export has been replaced by the
          Smart Export Guarantee (SEG) scheme but this income is dependent on
          agreement with your electricity supplier
        </li>
        <li>
          The calculations are based on a current electricity price of
          <%= electricity_tariff_£current_per_kwh_html %>,
          if mains electricity prices increase there will be a higher economic benefit and
          shorter payback to the installation.
        </li>
        <li>
          If the school becomes more efficient at using electricity and reduces its electricity
          consumption the benefit will also reduce.
        </li>
        <li>
          The capital costs in the table above are estimates based on
          current market rates; the installation cost at your
          school might be a little different - you need to get quotes.
        </li>
        <li>
          The estimates assume your have roof space and that is it roughly
          south facing - as this is optimal for schools whose peak demand is
          during the middle of the day when south facing panels produce the most electricity.
        </li>
        <li>
          The benefits of your solar pv will be reduced if you make your school more energy efficient.
          However, if you want your school to reduce its carbon emissions you should consider
          both installing solar panels and reducing your electricity consumption.
        </li>
      </ul>
    }
    ERB.new(text).result(binding)
  end

  def electricity_tariff_£current_per_kwh_html
    rate = @school.aggregated_electricity_meters.amr_data.current_tariff_rate_£_per_kwh
    FormatEnergyUnit.format(:£_per_kwh, rate, :html)
  end
end
