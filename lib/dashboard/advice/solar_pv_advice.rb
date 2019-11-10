class AdviceSolarPV < AdviceElectricityBase
  def relevance
    puts "QQQQQQ" * 1000
    @school.aggregated_electricity_meters.nil? ? :never_relevant : :relevant
  end

  def enough_data
    @school.solar_pv_panels? ? :enough : pv_benefit_estimator.enough_data
  end

  def pv_benefit_estimator
    @pv_benefit_alert ||= AlertSolarPVBenefitEstimator.new(@school)
  end

  def content
    @school.solar_pv_panels? ? super : solar_pv_benefit_content
  end

  def solar_pv_benefit_content
    pv_benefit_estimator.analyse(@school.aggregated_electricity_meters.amr_data.end_date)
    charts_and_html = []
    charts_and_html.push( { type: :html, content: '<h2>Benefits of installing solar PV</h2>' } )
    charts_and_html.push( { type: :html, content: introduction } )
    charts_and_html.push( { type: :html, content: table_intro } )
    charts_and_html.push( { type: :html, content: pv_benefit_estimator.solar_pv_scenario_table_html } )
    charts_and_html.push( { type: :html, content: table_explanation } )
    charts_and_html.push( { type: :html, content: caveats } )
    charts_and_html
  end

  def rating
    5.0
  end

  private

  def introduction
    %{
      <p>
        Installing solar pv at your school will reduce the electricity you consume from the national grid,
        and reduce your school&apos;s carbon emissions. It should be seen as an addition to reducing
        your school&apos;s electricity consumption through energy efficiency rather than an alternative.
        Economically, following the removal of subsidies from solar panels it might take
        between 10 and 15 years to payback the capital costs of installing solar panels, but
        PTAs will often be prepared to raise some of the capital costs making it more economi for schools.
      <p>
    }
  end

  def table_intro
    %{
      <p>
        The table below provides estimates of the potential benefits and costs of
        installing different quanitities of solar pv panels at your school:
      <p>
    }
  end

  def table_explanation
    text = %{
      <p>
        The table contains a range of capacities, calculated using half hourly electricity
        meter data from your school and real solar pv data for your locality for the last year
        to produce a reasonable estimate of the potential for solar pv to reduce your
        main consumption. Energy Sparks has also estimated that installing
        <%= FormatEnergyUnit.format(:kwp, pv_benefit_estimator.optimum_kwp, :html) %> you get the
        best payback, however, normally it the payback is relatively insensitive to
        the installed solar pv capacity.
      <p>
    }
    ERB.new(text).result(binding)
  end

  def caveats
    %{
      <p>Comments</p>
      <ul>
        <li>
          The calculations currently assume you will get some income from any
          exported electricity. Since the end of the Feed-In-Tariff in April 2019 there has
          been no replacement scheme to provide income from exported electricity. The
          government have proposed a Smart Export Guarantee (SEG) scheme, but
          it is not in place yet (as of Nov 2019) but some suppliers are
          already offering to pay you for any exported electricity.
        </li>
        <li>
          The capital costs in the table above are estimates based on
          current market rates; an installation cost at your
          school might be a little different.
        </li>
        <li>
          The estimates assume your have roof space and that is it roughly
          south facing - as this is optimal for schools whose peak demand is
          during the middle of the day when south facing panels produce most electricity.
        </li>
        <li>
          The benefits of your solar pv will be reduced if you make your school more energy efficient.
          However, if you want your school to reduce its carbon emissions you should consider 
          both installing solar panels and reducing your electricity consumption.
        </li>
      </ul>
    }
  end
end
