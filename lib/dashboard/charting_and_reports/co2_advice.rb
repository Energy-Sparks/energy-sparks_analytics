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
    when :electricity_co2_last_year_weekly_with_co2_intensity
      CO2ElectricityCO2LastYear.new(school, chart_definition, chart_data, chart_symbol)
    when :electricity_co2_last_7_days_with_co2_intensity
      CO2ElectricityCO2LastWeek.new(school, chart_definition, chart_data, chart_symbol)
    when :electricity_kwh_last_7_days_with_co2_intensity
      CO2ElectricitykWhLastWeek.new(school, chart_definition, chart_data, chart_symbol)
    when :gas_longterm_trend_kwh_with_carbon
      CO2GasCO2EmissionsLongTermTrends.new(school, chart_definition, chart_data, chart_symbol)
    when :group_by_week_carbon
      CO2GasCO2EmissionsLastYear.new(school, chart_definition, chart_data, chart_symbol)
    when :last_2_weeks_carbon_emissions
      CO2OverallEmissionQuestions.new(school, chart_definition, chart_data, chart_symbol)
    else
      nil
    end
  end

  class CO2AdviceBase < DashboardChartAdviceBase
    def initialize(chart_type, school, chart_definition, chart_data, advice_function = :co2)
      super(chart_type, school, chart_definition, chart_data)
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

    def model_standard_devation_table_html
      header = ['Model', 'Standard Deviation kWh', 'Standard Deviation (%)', 'Average R2', 'Average base temperature', 'Calculation time(ms)']
      rows = []
      rows.push(formatted_model_deviation_information(simple_model))
      rows.push(formatted_model_deviation_information(thermally_massive_model))
      rows.push(formatted_model_deviation_information(best_model)) if overridden_model?
      html_table(header, rows)
    end

    def formatted_model_deviation_information(model)
      [
        model.name,
        FormatEnergyUnit.format(:kwh, model.standard_deviation),
        (model.standard_deviation_percent * 100.0).round(1).to_s + '%',
        model.average_heating_school_day_r2.round(2),
        model.average_base_temperature.round(1).to_s + 'C',
        (model.model_calculation_time * 1000.0).to_i
      ]
    end

    def regression_parameters_html_table(model)
      sorted_models = best_model.sorted_model_keys(model.models)

      header = ['Name', 'A kWh/day', 'B kWh/day/C', 'R2', 'Base Temperature(C)','Samples', 'Example prediction kWh/day']
      rows = []
      sorted_models.each do |name, results|
        rows.push(
          [
            name,
            round_nan(results.a, 0),
            round_nan(results.b, 0),
            round_nan(results.r2, 2),
            round_nan(results.base_temperature, 1),
            results.samples,
            example_predicted_kwh(model, name, results)
          ]
        )
      end
      html_table(header, rows)
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
      <h1>
        School Carbon Emissions from Electricity and Gas Usage
      </h1>
      <p>
        Man-made carbon dioxide (CO<sub>2</sub>) emissions and other greenhouse
        gasses (e.g. methane CH<sub>4</sub>) are the primary cause of climate
        change. The emission of greenhouse gases into the atmosphere is causing the
      earth to warm up and increasing the frequency of extreme weather events. CO	<sub>2</sub> levels in the atmosphere have
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
          : The carbon emissions of transport used to get to the school (cars and
          buses use fossil fuels and emit carbon dioxide and other pollutants
          from their exhausts)
        </li>
        <li>
          <strong>Food</strong>
          : Food eaten at lunchtime, particularly from meat (cows emit a lot of
          CO<sub>2</sub> and methane as a result of eating grass, a vegetarian
          diet has half the carbon emissions of meat based diet)
        </li>
        <li>
          <strong>Electricity</strong>
          : From electricity used to power computers, lights and other appliances
          at the school
        </li>
        <li>
          <strong>Gas</strong>
          : From gas used to heat the school in the winter, for hot water and in
          school kitchens
        </li>
      </ul>
    ).freeze

    INTRO_TO_SCHOOL_CO2_GAS_AND_ELECTRICITY_2 = %q(
      <h2>
        Energy Sparks analysis of your school's greenhouse gas emissions from gas
        and electricity consumption
      </h2>
      <p>
        Energy Sparks can be used to analyse the carbon dioxide emissions from your
        school's electricity and gas consumption.
      </p>
      <p>
        The charts and analysis in Energy Sparks comes from your school's gas and
        electricity meters. Energy Sparks receives readings of how much energy the
        school has consumption from the school's smart meters which record energy
        consumption in kWh every half hour.
      </p>
      <p>
        Using this data Energy Sparks can accurately calculate the emissions from
        consumption of electricity and gas at your school by converting the energy
        used in kWh to CO<sub>2</sub> using 'carbon emission factors'.
      </p>
    ).freeze

    CARBON_EMISSION_FACTORS_3 = %q(
      <h2>
        Carbon Emission Factors
      </h2>
      <p>
        The calculate the school's carbon emissions from the consumption of gas and
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
      burnt in the school boilers 210g of CO<sub>2</sub> is emitted. CO	<sub>2</sub> is emitted as a result of burning gas (CH<sub>4</sub>) with
        oxygen (O<sub>2</sub>), to produce carbon dioxide (CO<sub>2</sub>) and
        water (H<sub>2</sub>0) (the chemical reaction is as follows CH<sub>4</sub>
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
        and nuclear power stations, solar photovoltaic panels and wind turbines
        which emit almost zero carbon when producing electricity. On a windy and
        sunny day when a larger proportion of the UK's electricity supply is from
        solar photovoltaic panels and wind turbines electricity emissions can be
        quite low at perhaps 100g of CO<sub>2</sub> per kWh of electricity, but on
        calm, cloudy days when most of the electricity is coming from gas and coal
        power stations as much as 400g of CO<sub>2</sub> is emitted for every 1 kWh
      of electricity production.	<a href="https://carbonintensity.org.uk/">This link</a> shows a graph of
        the electricity grid's carbon emissions today and has a brief video
        explaining the variability.
      </p>
      <p>
        The amount of carbon dioxide emitted by the UK National Electricity Grid
        has significantly declined over the last few year's as large number of
        solar photovoltaic panels (solar PV) have been installed and many offshore
        wind turbines have been installed replacing coal power stations which have
      been closed. Average annual emissions factors have declined from 500g CO	<sub>2</sub> per kWh in 2012 to about 230g per kWh in 2019.
      </p>
      <p>
        The table below shows where the UK National Electricity Grid has been
        sourcing its electricity from in the last 5 minutes:
      </p>
      <table border="1" cellspacing="0" cellpadding="0">
        <tbody>
          <tr>
            <td width="120" valign="top">
              <p>
                Solar
              </p>
            </td>
            <td width="120" valign="top">
            </td>
            <td width="120" valign="top">
            </td>
            <td width="120" valign="top">
            </td>
            <td width="120" valign="top">
            </td>
          </tr>
          <tr>
            <td width="120" valign="top">
              <p>
                Wind
              </p>
            </td>
            <td width="120" valign="top">
            </td>
            <td width="120" valign="top">
            </td>
            <td width="120" valign="top">
            </td>
            <td width="120" valign="top">
            </td>
          </tr>
          <tr>
            <td width="120" valign="top">
              <p>
                Nuclear
              </p>
            </td>
            <td width="120" valign="top">
            </td>
            <td width="120" valign="top">
            </td>
            <td width="120" valign="top">
            </td>
            <td width="120" valign="top">
            </td>
          </tr>
        </tbody>
      </table>
      ).freeze

      SCHOOL_CARBON_EMISSIONS_OVER_LAST_FEW_YEARS_4 = %q(
        <h1>
          Your School's Carbon Emissions over last few years
        </h1>
        <p>
          This chart shows your school's carbon emissions over the last few years.
          Generally, for most schools, unless they have managed to reduce gas
          consumption you would expect carbon emissions from gas to have remained
          relatively constant. However, for electricity, as a result of the national
          electricity grid's decarbonisation, replacing coal power stations with wind
          turbines, even without energy efficiency measures at school you would
          expect to see a decline in emissions. This chart shows your schools annual
          carbon emissions versus an average and an exemplar school of the same size
          (floor area, number of pupils):
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
        <p>
          For some schools we don't have enough historic meter readings to show many
          year's history of your carbon emissions, if this is the case you might want
          to pick another local similar school with more data on Energy Sparks to
          look at general longer-term trends in schools' carbon emissions?
        </p>
      ).freeze

    def generate_valid_advice
      header_template = concatenate_advice_with_body_start_end(
        [
          INTRO_TO_SCHOOL_CO2_1,
          INTRO_TO_SCHOOL_CO2_GAS_AND_ELECTRICITY_2,
          CARBON_EMISSION_FACTORS_3,
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
        This chart shows your school's electricity consumption in kWh over the last
        few years, with the average UK grid carbon intensity on the second Y2 axis:
      </p>
    ).freeze

    def generate_valid_advice
      header_template = concatenate_advice_with_body_start_end(LAST_FEW_YEARS_KWH_1)
      @header_advice = generate_html(header_template, binding)

      @footer_advice = nil_advice
    end
  end

  class CO2ElectricityCO2LongTerm < CO2AdviceBase
    LAST_FEW_YEARS_CO2_1 = %q(
      <p>
        This second chart shows your school's carbon emissions from electricity,
        for most schools this will have reduced, mainly as a result of the
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
      <h2>
        The carbon emissions of your school and the National Electricity Grid over
        the last year
      </h2>
      <p>
        The chart below shows the carbon emissions from electricity consumption of
        your school over the last year (bar chart), generally emissions are higher
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
      <h2>
        Variation in carbon emissions of your school over the last week
      </h2>
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
      <h2>
        Your School's Gas Carbon Emissions over the last few years
      </h2>
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
      <h2>
        Gas CO<sub>2</sub> emissions over the last year
      </h2>
      <p>
        Because most gas in schools is consumed for heating, CO<sub>2</sub>
        emissions from the consumption of gas in school is greater during the
        winter than the summer.
      </p>
      <p>
        This chart shows more detailed information, you should be able to see
        because more heating is required in the winter when it is cold then because
        more gas is being consumed (kWh) carbon dioxide emissions are higher:
      </p>
    ).freeze

    GAS_LAST_YEAR_CO2_QUESTIONS_2 = %q(
      <p>
        <strong>Question</strong>
        : because gas is a fossil fuel and the 'carbon factor' or emissions from
        burning 1 kWh of gas can't be reduced, how can the school reduce its gas
        emissions? What opportunities are there for reduction?
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

    def generate_valid_advice
      header_template = concatenate_advice_with_body_start_end(GAS_LAST_YEAR_CO2_1)
      @header_advice = generate_html(header_template, binding)

      footer_template = concatenate_advice_with_body_start_end(GAS_LAST_YEAR_CO2_QUESTIONS_2)
      @footer_advice = generate_html(footer_template, binding)
    end
  end
  
  class CO2OverallEmissionQuestions < CO2AdviceBase
    OVERALL_CO2_EMISSIONS_1 = %q(
      <h1>
        Calculating your school's total carbon emissions, including transport and
        food
      </h1>
      <p>
        As per the introduction to this web page, electricity and gas are not the
        only carbon emissions from a school; transport and consumption of food also
        contribute. The remainder of the webpage should help you calculate the
        additional greenhouse gas emissions from transport and food to get an
        overview of your school's total carbon emissions and perhaps where there
        may be opportunities to reduce your emissions.
      </p>
    ).freeze

    OVERALL_CO2_EMISSIONS_2 = %q(
      <h2>
        Question 1: Does your school emit more carbon for transport, or through gas
        and electricity, or from food consumed onsite?
      </h2>
      <p>
        The charts above on this webpage documents the carbon emissions from your
        school's electricity and gas consumption, but is this more or less than
        emissions from other sources like transport to and from your school, and
        from food eaten onsite?
      </p>
    ).freeze

    OVERALL_CO2_EMISSIONS_3 = %q(
      <h2>
        Calculation for example school
      </h2>
      <p>
        A calculation for an example school with 500 pupils might be as follows:
      </p>
      <p>
        <strong>Gas and electricity:</strong>
        the daily carbon emissions are 500kg of carbon per school day (read from an
        Energy Sparks graph,) see the graph for your school below.
      </p>
      <p>
        The chart below shows the carbon emissions on a daily basis of your school.
      </p>
      <p>
        <strong>Transport</strong>
        : the pupils at the example school counted 100 cars in the car park for
        school staff and reckoned that about 200 pupils were driven to school. Each
        of the school staff drove 20km there and back to school every day, and
        pupils were driven 6 km on average there and back. We also know that an
        average car emits 0.2kg of carbon for every km it is driven. So everyday
        staff drive 100 x 20km (2,000km), and pupils are driven 200 x 6km
        (1,200km), so 3,200 km in total. As a result, transport for the school will
        emit 3,200 * 0.2 = 640kg of carbon.
      </p>
      <p>
        <strong>Food</strong>
        : The process of producing (growing vegetable, meat) for an average meal
        results in the emissions of about 2kg of carbon per person per meal. If
        there are 500 pupils and 100 staff in the school that is 600 meals eaten at
        lunchtime, so, 2kg x 600 = 1200kg of emissions from food.
      </p>
      <p>
        So, in summary for this example school every day the carbon emissions are:
      </p>
      <ul>
        <li>
          500kg from gas and electricity (21%)
        </li>
        <li>
          640kg from transport (27%)
        </li>
        <li>
          1200kg from food (51%)
        </li>
      </ul>
      <p>
        So, 2340kg in total, with food consumed (at lunchtime) being the largest
        contributor.
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

    OVERALL_CO2_EMISSIONS_5 = %q(
        <p>
        And, then estimate how many kilometres of car journeys are taken too and
        from the school each day (buses emit 0.6kg/km per carry many more people
        than cars). And, then work out how many meals are consumed each day at your
        school, and repeat the calculation for your school in the same way as the
        calculation above.
      </p>
      <p>
        For your school which of the following emit the most carbon?
      </p>
      <ul>
        <li>
          Gas and electricity
        </li>
        <li>
          Transport
        </li>
        <li>
          Food
        </li>
      </ul>
    ).freeze

    OVERALL_CO2_EMISSIONS_Q2 = %q(
      <h1>
        Question 2: How can your school reduce its carbon emissions and meet the
        UK's future zero carbon emissions commitment?
      </h1>
      <p>
        The UK is committed to reducing its carbon emissions to zero by 2050, to
        try to avoid the worst impacts on the planet of climate change. To do this
        it needs the emissions from buildings (gas and electricity) to be zero by
        2035, so only 15 years' time (buildings need to go to zero emissions
        earlier, as reducing emissions from planes for example is more difficult
        and will be addressed after 2035).
      </p>
      <p>
        To reduce your school's carbon emissions to zero in 15 years, would mean
        reducing the school's emissions by about 7% every year (7% x 15 years is
        about 100%).
      </p>
      <p>
        Can you consider the following questions?
      </p>
      <p>
        &#183; Looking at the charts above is your school on-track to reduce its
        carbon emissions by 7% every year?
      </p>
      <p>
        &#183; The carbon intensity of the UK electricity grid is unlikely to
        continue reducing as fast as it has done recently once it gets to about
        0.1km/kWh in 2025, so emissions from gas will then have to be made - how do
        you think your school gas reduce its carbon emissions from using gas?
      </p>
      <p>
        &#183; Can you think of ways the school could reduce its emissions from
        transport and food?
      </p>
    ).freeze

    OVERALL_CO2_EMISSIONS_Q3 = %q(
      <h1>
        Question 3: Supply and demand; electricity grid carbon emissions
      </h1>
    ).freeze

    def generate_valid_advice
      header_template = concatenate_advice_with_body_start_end(
        [
          OVERALL_CO2_EMISSIONS_1,
          OVERALL_CO2_EMISSIONS_2,
          OVERALL_CO2_EMISSIONS_3,
          OVERALL_CO2_EMISSIONS_4
        ]
      )
      @header_advice = generate_html(header_template, binding)

      footer_template = concatenate_advice_with_body_start_end(
        [
          OVERALL_CO2_EMISSIONS_5,
          OVERALL_CO2_EMISSIONS_Q2,
          OVERALL_CO2_EMISSIONS_Q3
        ]
      )
      @footer_advice = generate_html(footer_template, binding)
    end
  end

  class CO2AdviceTemplateDoNothing < DashboardChartAdviceBase
    include Logging

    def generate_valid_advice
      @header_advice = nil_advice
      @footer_advice = nil_advice
    end
  end
end
