require 'erb'
require_relative 'dashboard_analysis_advice'

# extension of DashboardEnergyAdvice CO2 Advice Tab
# NB clean HTML from https://word2cleanhtml.com/cleanit
class DashboardEnergyAdvice

  def self.co2_advice_factory(chart_type, school, chart_definition, chart_data, chart_symbol)
    case chart_type
    when :benchmark_co2
      CO2IntroductionAndBenchmark.new(school, chart_definition, chart_data, chart_symbol)
    when :electricity_longterm_trend_kwh_with_carbon
      CO2ElectricityKwhLongTerm.new(school, chart_definition, chart_data, chart_symbol)
    when :electricity_longterm_trend_carbon
      CO2ElectricityCO2LongTerm.new(school, chart_definition, chart_data, chart_symbol)
    when :electricity_co2_last_year_weekly_with_co2_intensity_co2_only
      CO2ElectricityCO2LastYear.new(school, chart_definition, chart_data, chart_symbol)
    when :electricity_co2_last_7_days_with_co2_intensity
      CO2ElectricityCO2LastWeek.new(school, chart_definition, chart_data, chart_symbol)
    when :electricity_kwh_last_7_days_with_co2_intensity
      CO2ElectricitykWhLastWeek.new(school, chart_definition, chart_data, chart_symbol)
    when :gas_longterm_trend_kwh_with_carbon
      CO2GasCO2EmissionsLongTermTrends.new(school, chart_definition, chart_data, chart_symbol)
    when :group_by_week_carbon
      CO2GasCO2EmissionsLastYear.new(school, chart_definition, chart_data, chart_symbol)
    else
      nil
    end
  end

  class CO2AdviceBase < DashboardChartAdviceBase
    def initialize(school, chart_definition, chart_data, chart_symbol, advice_function = :co2)
      super(school, chart_definition, chart_data, chart_symbol)
      @advice_function = advice_function
    end

    def generate_advice
      if advice_valid?
        generate_valid_advice
      else
        header_template = %{
          <%= @body_start %>
            <p>
              <strong>This chart and advice are not relevent for this meter whose function is <%= meter_function_description %></strong>
            </p>
          <%= @body_end %>
        }.gsub(/^  /, '')

        @header_advice = generate_html(header_template, binding)

        @footer_advice = nil_advice
      end
    end
  
    def erb_bind(text)
      ERB.new(text).result(binding)
    end

    protected

    def meter_function_description
      @heat_meter.non_heating_only? ? 'non heating only' : (@heat_meter.heating_only? ? 'heating only' : 'heating and non heating')
    end

    def generate_valid_advice
      EnergySparksAbstractBaseClass.new('Call to heating model fitting advice base class not expected')
    end

    def advice_valid?
      true
    end

    # copied from heating_regression_model_fitter.rb TODO(PH,17Feb2019) - merge
    def html_table(header, rows)
      template = %{
        <p>
          <table class="table table-striped table-sm">
            <thead>
              <tr class="thead-dark">
                <% header.each do |header_titles| %>
                  <th scope="col"> <%= header_titles.to_s %> </th>
                <% end %>
              </tr>
            </thead>
            <tbody>
              <% rows.each do |row| %>
                <tr>
                  <% row.each do |val| %>
                    <td> <%= val %> </td>
                  <% end %>
                </tr>
              <% end %>
            </tbody>
          </table>
        </p>
      }.gsub(/^  /, '')
  
      generate_html(template, binding)
    end

    def concatenate_advice_with_body_start_end(advice_list)
      advice_list = [ advice_list ] unless advice_list.is_a?(Array)
      template =  %q{ <%= @body_start %> } +
                  advice_list.join(' ') +
                  %q{ <%= @body_end %> }

      template.gsub(/^  /, '')
    end
  end

  class CO2IntroductionAndBenchmark < CO2AdviceBase
    include Logging

    INTRO_TO_SCHOOL_CO2_1 = %q(
      <p>
        Man-made carbon dioxide (CO<sub>2</sub>) emissions and other greenhouse
        gasses (e.g. methane CH<sub>4</sub>) are the primary cause of climate
        change. The emission of greenhouse gases into the atmosphere is causing the
        earth to warm up and increasing the frequency of extreme weather events.
        CO	<sub>2</sub> levels in the atmosphere have
        <a
          href="https://climate.nasa.gov/climate_resources/24/graphic-the-relentless-rise-of-carbon-dioxide/"
          target="_blank"
        >
          increased by 30% in the last 50 years
        </a>
        as a result of man-made emissions.
      </p>
      <p>
        Schools are a source of greenhouse gas emissions, including:
      </p>
      <ul>
        <li>
          <strong>Transport</strong>
          : Most cars and buses used by pupils and staff to get to school use
          fossil fuels (petrol and diesel) and emit carbon dioxide and other
          pollutants from their exhausts
        </li>
        <li>
          <strong>Food</strong>
          : The production and transport of food eaten at lunchtime generates
          greenhouse gas emissions. A diet high in meat can generate a lot of
          greenhouse gases, as cows emit a lot of CO<sub>2</sub> and methane
          as a result of eating grass.
          A vegetarian diet has half the carbon emissions of meat-based diet.
        </li>
        <li>
          <strong>Electricity</strong>
          : The electricity used to power computers, lights and other appliances
          at the school is often generated in power stations
          which burn gas and coal (fossil fuels)
        </li>
        <li>
          <strong>Gas</strong>
          : The gas used to heat the school in the winter, to heat hot water and
          in cookers in the school kitchens, creates CO2 when it is burnt
        </li>
      </ul>
    ).freeze

    INTRO_TO_SCHOOL_CO2_GAS_AND_ELECTRICITY_2 = %q(
      <p>
        Energy Sparks can be used to analyse the carbon dioxide emissions from your
        school's electricity and gas consumption.
      </p>
      <p>
        Energy Sparks converts the energy used in kWh to CO<sub>2</sub> using 'carbon emission factors'.
      </p>
    ).freeze

    CARBON_EMISSION_FACTORS_3 = %q(
      <h2>
        Carbon Emission Factors
      </h2>
      <p>
        To calculate the school's carbon emissions from the consumption of gas and
        electricity we need to know how much carbon dioxide (CO<sub>2</sub>) is
        produced for every kWh of gas and electricity used by the school, these
        values are called 'emission factors', and they are different for gas and
        electricity.
      </p>
      <p>
        <strong>Gas emissions</strong>
      </p>
      <p>
        For gas the emissions are always the same; for every kWh of gas which is
        burnt in the school boilers 210g of CO<sub>2</sub> is emitted. CO	<sub>2</sub>
        is emitted as a result of burning gas (CH<sub>4</sub>) with
        oxygen (O<sub>2</sub>), to produce carbon dioxide (CO<sub>2</sub>) and
        water (H<sub>2</sub>0) (CH<sub>4</sub>
        + 4O<sub>2</sub> = CO<sub>2</sub> + 2H<sub>2</sub>O).
      </p>
      <p>
        So, if the school burns 1000 kWh of gas, it emits 1000 kWh * 210g /kWh =
        210,000g or 210kg of CO<sub>2</sub>.
      </p>
      <p>
        <strong>Electricity emissions</strong>
      </p>
      <p>
        Electricity is more complicated as it varies continuously depending on what
        power sources are being used to supply the National Electricity Grid, these
        include power stations which burn coal and gas which have high emissions,
        and nuclear power stations, solar photovoltaic (PV) panels and wind turbines
        which emit almost zero carbon when producing electricity. On a windy and
        sunny day when a larger proportion of the UK's electricity supply is from
        solar PV panels and wind turbines electricity emissions can be
        quite low at about 100g of CO<sub>2</sub> per kWh of electricity. On
        calm, cloudy days when most of the electricity is coming from gas and coal
        power stations as much as 400g of CO<sub>2</sub> is emitted for every 1 kWh
        of electricity production.
        <a href="https://carbonintensity.org.uk/" target="_blank">This link</a> shows
        a graph of the electricity grid's carbon emissions today and has a brief video
        explaining the variability.
      </p>
      <p>
        The amount of carbon dioxide emitted by the UK National Electricity Grid
        has significantly decreased over the last few year's as large number of
        solar PV panels and many offshore
        wind turbines have been installed replacing coal power stations which have
        been closed. Average annual emissions factors have decreased from 500g
        CO	<sub>2</sub> per kWh in 2012 to about 230g per kWh in 2019.
      </p>
      <p>
        The table below shows where the UK National Electricity Grid has been
        sourcing its electricity from in the last 5 minutes:
      </p>
      ).freeze

      SCHOOL_CARBON_EMISSIONS_OVER_LAST_FEW_YEARS_4 = %q(
        <h1>
          Your School's Carbon Emissions over the last few years
        </h1>
        <p>
          This chart shows your school's carbon emissions over the last few years.
          Unless your school has managed to reduce its gas consumption you would
          expect carbon emissions from gas to have remained relatively constant.
          However, for electricity, as a result of the national electricity grid's
          decarbonisation, you would expect to see a decline in emissions.
          This has happened even without energy efficiency measures at school
          and is due to coal power stations being replaced with wind turbines.
          This chart shows your schools annual carbon emissions compared to an
          average and an exemplar school of the same size: 
        </p>
      ).freeze

      QUESIONS_CARBON_EMISSIONS_OVER_LAST_FEW_YEARS_5 = %q(
        <p>
          <strong>Question</strong>
          : What are the carbon emission trends at your school? How does you school's
          carbon emissions compare with exemplar (the best), and regional and
          national averages for schools or the same size of yours?
        </p>
        <p>
          <strong>Question</strong>
          : Have both gas and electricity carbon emissions been reducing at your
          school?
        </p>
        <p>
          <strong>Question</strong>
          : Does your school emit more CO<sub>2</sub> from the consumption of
          electricity or gas?
        </p>
      ).freeze

      LIVE_UK_ELECTRICITY_GRID_SOURCES_TABLE_EXPLANATION = %q(
        <p>
          The first column of the table shows how much of the
          UK's electricity is being generated from that source.
        </p>
        <p>
          The second column is the amount of carbon emitted from generating 1 kWh of
          electricity from that source. Some of the renewable and 'low carbon'
          sources like solar, wind, hydro and nuclear still have a small carbon
          intensity because of the energy used in their manufacture e.g. wind
          turbines are made of steel, which takes energy to manufacture.
        </p>
        <p>
          The third column is the carbon contribution to the total cabron intensity
          from each source in kg CO2 per
          kWh of electricity produced.
        </p>
        <p>
          And, the final column is the UK's percentage of the
          total carbon emissions from each source.
        </p>
        <p>
          The carbon intensity of the National Electricity Grid is currently
          <%= FormatEnergyUnit.format(:kg_co2_per_kwh, current_grid_carbon_intensity, :html) %>.
          This is calculated by adding up all the carbon contributions in the 'Carbon
          Contribution' columns in the table above.
        </p>
        <p>
          The 'biomass' source comes from burning waste wood. 'Imports' are from
          electricity we get from other countries like Ireland, France, Netherlands
          and Norway through electricity cables running under the sea.
        </p>
        <p>
          <strong>Question</strong>
          : Which of the sources are emitting the most carbon? Why do you think this
          is?
        </p>
        <p>
          <strong>Question</strong>
          : On average over the last year the net carbon intensity of the National
          Electricity Grid was 0.24 kg CO2/kWh - how does this compare with the
          current value (see the paragraph above)? Generally, you would expect it to
          be below the figure on a sunny or windy day, but above on dull or calm
          days?
        </p>
      ).freeze

      COMPARISON_WITH_2018_ELECTRICITY_MIX = %q(
        <p>
          In 2018 the percentages of electricity generated from each source were:
        </p>
        <p>
          <%= grid_carbon_intensity_2018_html_table %>
        </p>
        <p>
          <strong>Question</strong>
          : How does that compare with the first table which contains todays
          electricity sources? Why do you think they differ?
        </p>
      ).freeze

    private def uk_grid_sources
      @uk_grid_sources ||= UKElectricityGridMix.new
    end

    private def grid_carbon_intensity_2018_html_table
      convert_grid_intensity_to_html_table(uk_grid_sources.carbon_intensity_table_2018)
    end

    public def grid_carbon_intensity_live_html_table
      convert_grid_intensity_to_html_table(uk_grid_sources.carbon_intensity_table_live)
    end

    private def current_grid_carbon_intensity
      uk_grid_sources.net_carbon_intensity_live
    end

    private def convert_grid_intensity_to_html_table(grid_intensity)
      sorted_data = grid_intensity.sort_by {|_fuel_source, data|  -data[:percent] }

      formatted_data = []
      sorted_data.each do |fuel_source, data|
        formatted_data.push(
          [
            fuel_source,
            FormatEnergyUnit.format(:percent, data[:percent], :html),
            FormatEnergyUnit.format(:kg_co2_per_kwh, data[:intensity], :html, false, true),
            FormatEnergyUnit.format(:kg_co2_per_kwh, data[:carbon_contribution], :html, false, true),
            FormatEnergyUnit.format(:percent, data[:carbon_percent], :html)
          ]
        )
      end

      header = ['Source', 'Percent of Energy', 'Carbon Intensity (kg CO2/kWh)', 'Carbon Contribution (kg CO2/kWh)', 'Percentage of Carbon']

      html_table(header, formatted_data)
    end

    def generate_valid_advice

      header_template = concatenate_advice_with_body_start_end(
        [
          INTRO_TO_SCHOOL_CO2_1,
          INTRO_TO_SCHOOL_CO2_GAS_AND_ELECTRICITY_2,
          CARBON_EMISSION_FACTORS_3,
          grid_carbon_intensity_live_html_table,
          LIVE_UK_ELECTRICITY_GRID_SOURCES_TABLE_EXPLANATION,
          COMPARISON_WITH_2018_ELECTRICITY_MIX,
          SCHOOL_CARBON_EMISSIONS_OVER_LAST_FEW_YEARS_4
        ]
      )

      @header_advice = generate_html(header_template, binding)

      footer_template = concatenate_advice_with_body_start_end(QUESIONS_CARBON_EMISSIONS_OVER_LAST_FEW_YEARS_5)
      @footer_advice = generate_html(footer_template, binding)
    end
  end

  class CO2ElectricityKwhLongTerm < CO2AdviceBase
    include Logging

    LAST_FEW_YEARS_KWH_1 = %q(
      <h2>
        Your School's Electricity Carbon Emissions over the last few years
      </h2>
      <p>
        This chart shows your school's electricity consumption over the last
        few years, with the average UK grid carbon intensity on the second y axis:
      </p>
    ).freeze

    SUGGEST_SWITCHING_YAXIS_UNITS = %q(
      <p>
        Try switching between between the units (Change units: kWh, £ or kg CO2) and drilling
        down by clicking on the bars.
      </p>
    )

    LAST_FEW_YEARS_CO2_QUESTION_2 = %q(
      <p>
        <strong>Question</strong>
        : By switching the Y axis between kWh and kg CO2 has your school
        reduced its carbon emissions more from reducing its electricity
        energy consumption (kWh) or from the National Electricity Grid decarbonisation?
      </p>
    ).freeze

    POST_CHART_ADVICE = [SUGGEST_SWITCHING_YAXIS_UNITS, LAST_FEW_YEARS_CO2_QUESTION_2]

    def generate_valid_advice
      header_template = concatenate_advice_with_body_start_end(LAST_FEW_YEARS_KWH_1)
      @header_advice = generate_html(header_template, binding)

      @footer_advice = concatenate_advice_with_body_start_end(POST_CHART_ADVICE)
    end
  end

  class CO2ElectricityCO2LongTerm < CO2AdviceBase
    LAST_FEW_YEARS_CO2_1 = %q(
      <p>
        This second chart shows your school's carbon emissions from electricity.
        For most schools this will have reduced, mainly as a result of the
        decarbonisation of the National Electricity Grid rather than from reduced
        electricity consumption:
      </p>
    ).freeze

    LAST_FEW_YEARS_CO2_QUESTION_2 = %q(
      <p>
        <strong>Question</strong>
        : Looking at the 2 charts has your school reduced its carbon emissions more
        from reducing its electricity energy consumption (kWh) or from the National
        Electricity Grid decarbonisation?
      </p>
    ).freeze

    def generate_valid_advice
      header_template = concatenate_advice_with_body_start_end(LAST_FEW_YEARS_CO2_1)
      @header_advice = generate_html(header_template, binding)

      footer_template = concatenate_advice_with_body_start_end(LAST_FEW_YEARS_CO2_QUESTION_2)
      @footer_advice = generate_html(footer_template, binding)
    end
  end

  class CO2ElectricityCO2LastYear < CO2AdviceBase
    LAST_YEAR_CO2_1 = %q(
      <p>
        The chart below shows the carbon emissions from electricity consumption of
        your school over the last year. Generally emissions are higher
        during the winter as more electricity is used for lighting and sometimes
        for heating:
      </p>
    ).freeze

    LAST_YEAR_CO2_QUESTIONS_2 = %q(
      <p>
        The line (right hand axis) shows how the carbon emissions of the grid have
        varied in intensity as a result of the ever-changing mix of electricity
        sources on the grid. Generally, the intensity of the National Electricity
        Grid is higher in winter, when demand is highest and there are not enough
        renewable (wind, solar) and low carbon (nuclear) sources to satisfy demand,
        and when electricity from gas power stations which emit carbon must be
        turned on to meet this extra demand.
      </p>
      <p>
        <strong>Question</strong>
        : Can you see these trends in the chart above for your school?
      </p>
      <p>
        <strong>Question</strong>
        : At what time of year do you think the most electricity is produced from
        wind turbines and solar PV? Are they at different times of the year?
      </p>
    ).freeze

    def generate_valid_advice
      header_template = concatenate_advice_with_body_start_end(LAST_YEAR_CO2_1)
      @header_advice = generate_html(header_template, binding)

      footer_template = concatenate_advice_with_body_start_end(LAST_YEAR_CO2_QUESTIONS_2)
      @footer_advice = generate_html(footer_template, binding)
    end
  end

  class CO2ElectricityCO2LastWeek < CO2AdviceBase
    LAST_WEEK_CO2_1 = %q(
      <p>
        The graph below shows the carbon emissions (bar charts. Left hand axis)
        from your school as a result of electricity consumption over the last week,
        versus the carbon intensity of the National Electricity Grid (line, right
        hand axis):
      </p>
    ).freeze

    LAST_WEEK_CO2_QUESTIONS_2 = %q(
      <p>
        <strong>Question</strong>
        : How much carbon has the intensity of the UK National Electricity Grid
        varied over the last week? What was the highest and lowest carbon
        intensities? Are the highest and lowest intensities at particular times
        during the week, when perhaps demand is highest and lowest?
      </p>
    ).freeze

    def generate_valid_advice
      header_template = concatenate_advice_with_body_start_end(LAST_WEEK_CO2_1)
      @header_advice = generate_html(header_template, binding)

      footer_template = concatenate_advice_with_body_start_end(LAST_WEEK_CO2_QUESTIONS_2)
      @footer_advice = generate_html(footer_template, binding)
    end
  end

  class CO2ElectricitykWhLastWeek < CO2AdviceBase
    LAST_WEEK_KWH_4 = %q(
      <hr>
      <h2>Variation in your school's electricity carbon emissions during the last week</h2>
      <p>
        <strong>Question</strong>
        : How has the carbon intensity of the National Electricity Grid impacted
        the carbon emissions of your school this week? Compare it with your
        electricity consumption (in on this chart):
      </p>
    ).freeze

    LAST_WEEK_KWH_QUESTIONS_5 = %q(
      <p>
        Demand is generally highest on weekdays when people are at work and at
        school, but the intensity can be reduced if it is a sunny day in the summer
        from solar PV panels which are zero carbon reducing the need to produce
        electricity from gas power stations which emit a lot of carbon (about
        0.36kg/kWh).
      </p>
    ).freeze

    def generate_valid_advice
      header_template = concatenate_advice_with_body_start_end(LAST_WEEK_KWH_4)
      @header_advice = generate_html(header_template, binding)

      footer_template = concatenate_advice_with_body_start_end(LAST_WEEK_KWH_QUESTIONS_5)
      @footer_advice = generate_html(footer_template, binding)
    end
  end

  class CO2GasCO2EmissionsLongTermTrends < CO2AdviceBase
    GAS_LONG_TERM_CO2_1 = %q(
      <p>
        Gas is consumed by schools to provide heating in the winter, and for
        heating hot water, and kitchen usage all year round.
      </p>
      <p>
        The chart below shows your school's gas consumption over the last few
        years:
      </p>
    ).freeze

    GAS_LONG_TERM_CO2_QUESTIONS_2 = %q(
      <p>
        Unlike the National Electricity Grid the carbon intensity of gas hasn't
        changed over many years; there are a few energy companies offering 'biogas'
        (typically gas from waste food or sewage), but this has very limited impact
        on the carbon emissions of gas.
      </p>
      <p>
        <strong>Question</strong>
        : Has your school's carbon emissions from gas changed in the last few
        years?
      </p>
      <p>
        <strong>Question</strong>
        : How does the carbon emissions of gas compare with the carbon emissions of
        the electricity grid, today?
      </p>
    ).freeze

    def generate_valid_advice
      header_template = concatenate_advice_with_body_start_end(GAS_LONG_TERM_CO2_1)
      @header_advice = generate_html(header_template, binding)

      footer_template = concatenate_advice_with_body_start_end(GAS_LONG_TERM_CO2_QUESTIONS_2)
      @footer_advice = generate_html(footer_template, binding)
    end
  end

  class CO2GasCO2EmissionsLastYear < CO2AdviceBase
    GAS_LAST_YEAR_CO2_1 = %q(
      <p>
        As most gas in schools is consumed for heating, CO<sub>2</sub>
        emissions from the consumption of gas in school is greater during the
        winter than the summer.
      </p>
    ).freeze

    GAS_LAST_YEAR_CO2_QUESTIONS_2 = %q(
      <p>
        <strong>Question</strong>
        : As gas is a fossil fuel and the 'carbon factor' or emissions from
        burning 1 kWh of gas can't be reduced, how can the school reduce its gas
        emissions?
      </p>
      <p>
        <strong>Answer</strong>
        : The only way for a school to reduce carbon emissions from its gas
        consumption is to use less gas: making sure the heating and hot water are
        not left on during holidays, weekends or school hours, and turning the
        thermostat down. An alternative might be to replace the gas boiler with and
        'air source heat pump' which uses electricity but emits much less carbon,
        but this can be expensive to install.
      </p>
    ).freeze
    OVERALL_CO2_EMISSIONS_1 = %q(
      <p>
        Electricity and gas are not the
        only carbon emissions from a school; transport and consumption of food also
        contribute. This should help you calculate the
        additional greenhouse gas emissions from transport and food to get an
        overview of your school's total carbon emissions and perhaps where there
        may be opportunities to reduce your emissions.
      </p>
      <p>
        For most schools about 30% of carbon emissions come from gas and
        electricity consumption, 30% from food and 30% from transport.
      </p>
      <p>
        To calculate your school's total carbon emissions, you will need to do some
        research:
      </p>
      <ul>
        <li>
          <strong>Transport</strong>
          : You will need to find out how staff and pupils get to school, either
          my doing a survey, or by asking school management if a survey has been
          done in the past
        </li>
        <li>
          <strong>Food</strong>
          : You will need to count how many meals are eaten at school each day
          (normally one of each pupil and staff member), and how many of these
          are meat based, and how many vegetarians?
        </li>
        <li>
          <strong>Gas and electricity</strong>
          : You just need to find the information on Energy Sparks
        </li>
      </ul>
      <p>
        Once you have gathered the information you will then need to enter the data
        into this spreadsheet:
      </p>
    ).freeze

    OVERALL_CO2_EMISSIONS_2 = %q(
      <p>
        It might be best if you download a copy of the spreadsheet (button bottom
        right), so you can save the information for future use. You need to fill in
        the information in the cells coloured orange which have been pre-populated
        for an example school with 400 pupils.
      </p>
      <p>
        The next section tells you how to gather the data required for each of the
        types of carbon emissions (gas, electricity, transport, food).
      </p>
    ).freeze

    OVERALL_CO2_EMISSIONS_TRANSPORT_3 = %q(
      <h3>
        1. Transport
      </h3>
      <p>
        To calculate the 'transport' carbon emissions of a school you need to find
        out how people, both staff and pupils travel to school, and how far they
        travel. For this you might need to do a survey, or school management might
        already know if a 'Transport Survey' has already been carried out at a
        school.
      </p>
      <p>
        You need to determine how everyone gets to school. The most important
        information to find is how many people travel to school by car and how far
        they travel, as cars generally generate the most carbon emissions,
        accounting for more than 90% of transport carbon emissions at most schools.
      </p>
      <p>
        You need to find the following information for the spreadsheet (Transport
        Tab):
      </p>
      <p>
        <img src="https://lhjawq.sn.files.1drv.com/y4m4xygPzQJ7Qaa2kBkzr9pFBPk0liVNrxne0pLmHDWh1BB2AsBQqViHRLNq_g4D6DJE1sPd8baRNkU6QtwNF3EzLGmZ-8MsceWWQ-kMwCmQJ-bRRrizK-3kdFrZaDRrEEDldeDmW6iXLQSND8b7MA4ZcfXbNTdFHEPrVlGhnGAHce8l9Gy6yAcQGqFOIjJGu32Q4EiDSWJzStc9OatPNjYXg?width=539&height=539&cropmode=none" width="539" height="539" />
      </p>
      <p>
        The easiest way is to survey the staff, create a form containing 3 columns,
        the first with the name of the staff member, and the how they get to work,
        and the third with the average distance they travel, and then ask them to
        provide you with the information e.g.
      </p>

      <table class="table table-striped table-sm">
      <thead>
      <tr class="thead-dark">
          <th scope="col"> Staff member </th>
          <th scope="col"> Transport Mode </th>
          <th scope="col"> Average daily return distance </th>
      </tr>
    </thead>
        <tbody>
          <tr>
            <td width="200" valign="top">
              <p>
                Mrs Smith
              </p>
            </td>
            <td width="200" valign="top">
              <p>
                Petrol car
              </p>
            </td>
            <td width="200" valign="top">
              <p>
                12
              </p>
            </td>
          </tr>
          <tr>
            <td width="200" valign="top">
              <p>
                Mr Jones
              </p>
            </td>
            <td width="200" valign="top">
              <p>
                Bus
              </p>
            </td>
            <td width="200" valign="top">
              <p>
                6
              </p>
            </td>
          </tr>
          <tr>
            <td width="200" valign="top">
              <p>
                Ms Khan
              </p>
            </td>
            <td width="200" valign="top">
              <p>
                Petrol Car
              </p>
            </td>
            <td width="200" valign="top">
              <p>
                10
              </p>
            </td>
          </tr>
        </tbody>
      </table>
      <p>
        You then need to calculate the number of staff travelling by each mode and
        the average distance for each Transport Mode - you might need to get a
        member of staff to help you with this. For the example above, you would
        need to enter under Staff - Petrol car: 2 staff (number) and an average
        distance of 11 miles (average of 10 and 12 miles), and under Staff - Bus: 1
        staff member and an average of 6 miles.
      </p>
      <p>
        To survey the figures for pupils you might need to survey pupils as they
        arrive at school but asking them to fill in a form for you, or you could
        print out and send a survey home.
      </p>
    ).freeze

    OVERALL_CO2_EMISSIONS_4 = %q(
      <h2>
        Calculation for your school
      </h2>
      <p>
        Now, see if you can do the calculation for your school, you will need to
        read off the electricity and gas consumption for an example day for your
        school from the chart below:
      </p>
    ).freeze

    OVERALL_CO2_EMISSIONS_FOOD_4 = %q(
      <h3>
        2. Food
      </h3>
      <p>
        Food is much easier to calculate. You just need to find out how many people
        eat meat-based meals at school each day and how many are vegetarian and
        enter them into the spreadsheet. Most people at the school will eat lunch
        every day, some will be supplied by the school kitchen (you could ask the
        kitchen staff how many meat based and vegetarian meals they serve each
        day), and also packed lunches.
      </p>
      <p>
        Once you have gathered this information you simply enter the 2 numbers into
        the 'Food' tab of the spreadsheet.
      </p>
    ).freeze

    OVERALL_CO2_EMISSIONS_ENERGY_5 = %q(
      <h2>
        3. Electricity and gas
      </h2>
      <p>
        Energy Sparks can calculate this for you automatically if there is at least
        a year of electricity and gas meter readings.
      </p>
      <p>
        Energy Sparks has calculated the following values for your school:
      </p>
      <% if @school.electricity? %>
        <p>
          &#183; Electricity: <%= FormatEnergyUnit.format(:co2, annual_electricity_co2) %> /year
        </p>
      <% end %>
      <% if @school.gas? %>
        <p>
          &#183; Gas: <%= FormatEnergyUnit.format(:co2, annual_gas_co2) %> /year
        </p>
      <% end %>
      <p>
        You just need to enter these values in the 'Electric+Gas' tab in the
        spreadsheet.
      </p>
    ).freeze

    OVERALL_CO2_EMISSIONS_TOTAL_6 = %q(
      <h3>
        Totals
      </h3>
      <p>
          Once you have entered the information on the 3 tabs you can look at the
          result on the &#8216;Totals&#8217; tab. The pie chart should show about 30%
          of carbon emissions at your school coming from each of transport, food and
          energy (electricity and gas).
      </p>
    ).freeze

    OVERALL_CO2_EMISSIONS_QUESTIONS_7 = %q(
      <h2>
        Devising a strategy for reducing your school's carbon emissions
      </h2>
      <p>
        After calculating your school's current carbon emissions,
        perhaps you could consider how you might help
        the school reduce its carbon emissions and reduce the impact of global
        warming?
      </p>
      <p>
        Suggestions include:
      </p>
      <p>
        1. <strong>Transport</strong>:
      </p>
      <p>
        &#183; Getting more people to walk, cycle and take the bus to school and
        fewer driving (which also causes air pollution which is bad for your
        health)
      </p>
      <p>
        &#183; Car sharing: sharing a car reduces per person carbon emissions
      </p>
      <ul>
        <li>
          Switching from petrol to electric cars (you could try
            <a href="https://energysparks.uk/activity_types/75" target="_blank">this activity</a>)
        </li>
      </ul>
      <p>
        2. <strong>Food</strong>:
      </p>
      <p>
        &#183; We all have to eat, but perhaps we could eat more vegetarian food,
        which has about 60% of the carbon emissions of a meat-based meal
      </p>
      <p>
        3. <strong>Energy</strong>:
      </p>
      <p>
        &#183; Reducing your school's energy consumption is the simplest solution.
        Use Energy Sparks to determine the best way of saving energy; the
        easiest ways are to make sure heating and hot water are not left on over
        weekends, and holidays, to turn appliances and lighting off, and to make
        sure the school purchases the most efficient equipment when replacing
        appliances. Specific suggestions, using information which Energy Sparks
        has calculated for your school include:
      </p>
      <ul>
        <%= energy_reduction_suggestions %>
      </ul>
      <p>
        Put together a plan to achieve each of these. Re-enter the new numbers
        into the spreadsheet and see how much carbon the school will save?
      </p>
      <p>
        To stop catastrophic global warming the UK has committed to reduce its
        carbon emissions to zero by 2050, which is about 4% per year. Can you come
        up with a plan for your school for the next 5 years which would reduce its
        carbon emissions by 20%?
      </p>
    ).freeze

    EMBEDDED_EXCEL_CARBON_CALCULATOR = %q(
      <iframe width="800" height="450" frameborder="0" scrolling="no" src="https://onedrive.live.com/embed?resid=D22255E34EA12530%21278999&authkey=%21AA4vdwZUz8mhacQ&em=2&wdAllowInteractivity=False&AllowTyping=True&ActiveCell='Totals'!A1&wdHideGridlines=True&wdHideHeaders=True&wdDownloadButton=True&wdInConfigurator=True"></iframe>
      )

    private def annual_electricity_co2
      @annual_electricity_co2 ||= ScalarkWhCO2CostValues.new(@school).aggregate_value({year: 0}, :allelectricity_unmodified, :co2)
    end

    private def annual_electricity_kwh
      @annual_electricity_kwh ||= ScalarkWhCO2CostValues.new(@school).aggregate_value({year: 0}, :allelectricity_unmodified, :kwh)
    end

    private def annual_gas_co2
      @annual_gas_co2 ||= ScalarkWhCO2CostValues.new(@school).aggregate_value({year: 0}, :gas, :co2)
    end

    private def last_year_carbon_intensity_kg_per_kwh
      @last_year_carbon_intensity ||= annual_electricity_co2 / annual_electricity_kwh
    end

    private def energy_reduction_suggestions
      [
        gas_reduction_suggestions,
        electricity_reduction_suggestions
      ].flatten.compact.join(' ')
    end

    private def gas_reduction_suggestions
      [
        gas_reduction_from_turning_off_out_of_hours,
        turn_thermostat_down
      ].compact
    end

    private def gas_reduction_from_turning_off_out_of_hours
      return '' if !@school.gas?
      suggestion = ''
      co2 = ScalarkWhCO2CostValues.new(@school).day_type_breakdown({year: 0}, :gas, :co2, false, false)
      percent = ScalarkWhCO2CostValues.new(@school).day_type_breakdown({year: 0}, :gas, :co2, false, true)
      if percent['School Day Open'] < 0.75
        non_school_hours_percent = 1.0 - percent['School Day Open']
        co2_saving = co2.map { |daytype, value| ['Holiday', 'Weekend', 'School Day Closed'].include?(daytype) ? value : 0.0 }
        suggestion += '<li> You could reduce the schools gas CO2 emissions by ' +
                      FormatEnergyUnit.format(:percent, non_school_hours_percent, :html) +
                      ' by turning your heating and hot water off out of school hours, ' +
                      ' during weekends and holidays, saving ' +
                      FormatEnergyUnit.format(:co2, co2_saving.sum, :html) +
                      ' per year. </li>'
      end
      suggestion
    end

    private def turn_thermostat_down
      return '' if !@school.gas?
      aggregate_gas_amr = @school.aggregated_heat_meters.amr_data
      last_year = SchoolDatePeriod.year_to_date(:year_to_date, 'validate amr', aggregate_gas_amr.end_date, aggregate_gas_amr.start_date)
      model = @school.aggregated_heat_meters.heating_model(last_year)
      saving_kwh = model.kwh_saving_for_1_C_thermostat_reduction(last_year.start_date, last_year.end_date)
      saving_co2_per_1c = saving_kwh * EnergyEquivalences::UK_GAS_CO2_KG_KWH
      saving_percent_per_1c = saving_co2_per_1c / annual_gas_co2
      '<li> For every 1C you turn the thermostat down by you would save ' +
      FormatEnergyUnit.format(:co2, saving_co2_per_1c, :html) +
      ' or ' +
      FormatEnergyUnit.format(:percent, saving_percent_per_1c, :html) +
      ' of your gas CO2 emissions</li>'
    end

    private def reducing_baseload_by_10_percent
      return '' if !@school.electricity?
      aggregate_electric_amr = @school.aggregated_unaltered_electricity_meters.amr_data
      start_date = [aggregate_electric_amr.start_date, aggregate_electric_amr.end_date - 365].max
      average_baseload_kw = aggregate_electric_amr.average_baseload_kw_date_range(start_date, aggregate_electric_amr.end_date)
      annual_10_percent_baseload_kwh = average_baseload_kw * 365 * 24 * 0.1
      percent_of_annual_kwh_10_percent_baseload_reduction = annual_10_percent_baseload_kwh / annual_electricity_kwh
      annual_co2_reduction_from_10_percent_baseload_reduction = annual_electricity_co2 * percent_of_annual_kwh_10_percent_baseload_reduction

      '<li> Every 10 &percnt; reduction in electricity baseload would save ' +
      FormatEnergyUnit.format(:co2, annual_co2_reduction_from_10_percent_baseload_reduction, :html) +
      ' or ' +
      FormatEnergyUnit.format(:percent, percent_of_annual_kwh_10_percent_baseload_reduction, :html) +
      ' of your annual electricity CO2 emissions </li>'
    end

    private def solar_panel_co2_reduction_per_10_panels(panels = 10)
      return '' if !@school.electricity?
      panel_kwp = 0.3
      panel_yield_kwh_per_kwp = 900
      annual_panel_kwh = panel_kwp * panel_yield_kwh_per_kwp
      panel_annual_co2_saving = annual_panel_kwh * last_year_carbon_intensity_kg_per_kwh
      annual_co2_saving_10_panels = panels * panel_annual_co2_saving
      annual_kwh_saving = panels * annual_panel_kwh / annual_electricity_kwh

      '<li>For every ' + panels.to_s + ' solar PV panels you install you could save ' +
      FormatEnergyUnit.format(:co2, annual_co2_saving_10_panels, :html) +
      ' or ' +
      FormatEnergyUnit.format(:percent, annual_kwh_saving, :html) +
      ' of your annual electricity CO2 emissions</li>'
    end

    private def electricity_reduction_suggestions
      [
        reducing_baseload_by_10_percent,
        solar_panel_co2_reduction_per_10_panels
      ].compact
    end

    def generate_valid_advice
      header_template = concatenate_advice_with_body_start_end(GAS_LAST_YEAR_CO2_1)
      @header_advice = generate_html(header_template, binding)

      footer_template = concatenate_advice_with_body_start_end(
        [
          GAS_LAST_YEAR_CO2_QUESTIONS_2,
          OVERALL_CO2_EMISSIONS_1,
          EMBEDDED_EXCEL_CARBON_CALCULATOR,
          OVERALL_CO2_EMISSIONS_2,
          OVERALL_CO2_EMISSIONS_TRANSPORT_3,
          OVERALL_CO2_EMISSIONS_FOOD_4,
          OVERALL_CO2_EMISSIONS_ENERGY_5,
          OVERALL_CO2_EMISSIONS_TOTAL_6,
          OVERALL_CO2_EMISSIONS_QUESTIONS_7
        ]
      )
      @footer_advice = generate_html(footer_template, binding)
    end
  end
end
