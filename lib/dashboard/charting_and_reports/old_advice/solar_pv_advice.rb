require 'erb'

# extension of DashboardEnergyAdvice for solar pv advice
# NB clean HTML from https://word2cleanhtml.com/cleanit
class DashboardEnergyAdvice

  def self.solar_pv_advice_factory(chart_type, school, chart_definition, chart_data, chart_symbol)
    case chart_type
    when :solar_pv_group_by_month, :management_dashboard_group_by_month_solar_pv
      SolarPVVersusIrradianceLastYearAdvice.new(school, chart_definition, chart_data, chart_symbol)
    when :solar_pv_group_by_month_dashboard_overview
      SolarPVVersusIrradianceLastYearOverviewAdvice.new(school, chart_definition, chart_data, chart_symbol)
    when :solar_pv_last_7_days_by_submeter
      SolarPVLast7Days.new(school, chart_definition, chart_data, chart_symbol)
    else
      nil
    end
  end

  class SolarPVAdviceBase < DashboardChartAdviceBase
    attr_reader :solar_pv_profit_loss
    def initialize(school, chart_definition, chart_data, chart_symbol)
      super(school, chart_definition, chart_data, chart_symbol)
      @solar_pv_profit_loss = SolarPVProfitLoss.new(@school)
    end

    def annual_electricity_including_onsite_solar_pv_consumption_kwh_html
      FormatEnergyUnit.format(:kwh, solar_pv_profit_loss.annual_electricity_including_onsite_solar_pv_consumption_kwh,  :html, false, false, :approx_accountant)
    end

    def annual_solar_pv_kwh_html
      FormatEnergyUnit.format(:kwh, solar_pv_profit_loss.annual_solar_pv_kwh,  :html, false, false, :approx_accountant)
    end

    def annual_solar_pv_consumed_onsite_kwh_html
      FormatEnergyUnit.format(:kwh, solar_pv_profit_loss.annual_solar_pv_consumed_onsite_kwh,  :html, false, false, :approx_accountant)
    end

    def annual_solar_pv_consumed_onsite_£_html
      saving_£ = solar_pv_profit_loss.annual_solar_pv_consumed_onsite_kwh * BenchmarkMetrics.pricing.electricity_price
      FormatEnergyUnit.format(:£, saving_£,  :html, false, false, :ks2)
    end

    def annual_exported_solar_pv_£_html
      export_£ = solar_pv_profit_loss.annual_exported_solar_pv_kwh * BenchmarkMetrics.pricing.solar_export_price
      FormatEnergyUnit.format(:£, export_£,  :html, false, false, :ks2)
    end

    def annual_exported_solar_pv_kwh_html
      FormatEnergyUnit.format(:kwh, solar_pv_profit_loss.annual_exported_solar_pv_kwh,  :html, false, false, :approx_accountant)
    end

    def annual_saving_from_solar_pv_percent_html
      FormatEnergyUnit.format(:percent, solar_pv_profit_loss.annual_saving_from_solar_pv_percent,  :html, false, false, :ks2)
    end

    def annual_consumed_from_national_grid_kwh_html
      FormatEnergyUnit.format(:kwh, solar_pv_profit_loss.annual_consumed_from_national_grid_kwh,  :html, false, false, :approx_accountant)
    end

    def annual_co2_saving_kg_html
      FormatEnergyUnit.format(:co2, solar_pv_profit_loss.annual_co2_saving_kg,  :html)
    end

    def summary_pv_table_data_html
      [
        [
          [ 'Photovoltaic production',  annual_solar_pv_kwh_html ],
          [ 'Export to the network',    annual_exported_solar_pv_kwh_html ],
          [ 'Self-consumption',         annual_solar_pv_consumed_onsite_kwh_html ],
          [ 'Consumption from network', annual_consumed_from_national_grid_kwh_html]
        ],
        [ 'Total consumption', annual_electricity_including_onsite_solar_pv_consumption_kwh_html ]
      ]
    end

    def formatted_summary_table_html
      data, total = summary_pv_table_data_html
      html_table(nil, data, total)
    end

    protected def pv_util
      @pv_util ||= SolarPVUtilities.new(@school)
    end

    protected def period_introduction
      if pv_util.full_years_solar_installation?
        'over the last year'
      else
        text = %{
          since they were installed in
          <%= pv_util.install_month_year_text %>
        }.gsub(/^  /, '')
        ERB.new(text).result(binding)
      end
    end

    private def electricity_price_£current_per_kwh
      @school.aggregated_electricity_meters.amr_data.blended_rate(:kwh, :£current).round(5)
    end

    private def electricity_price_£current_per_kwh_html
      FormatEnergyUnit.format(:£_per_kwh, electricity_price_£current_per_kwh, :html)
    end
  end 

  class SolarPVVersusIrradianceLastYearAdvice < SolarPVAdviceBase

    protected def format_row(row)
      [
        row[:name],
        FormatEnergyUnit.format(:kwh,       row[:kwh],  :html, false, true, :approx_accountant),
        row[:rate].nil? ? '' : FormatEnergyUnit.format(:£_per_kwh, row[:rate], :html, false, true),
        FormatEnergyUnit.format(:£,         row[:£],    :html, false, true, :approx_accountant)
      ]
    end

    def generate_advice
      @header_advice = generate_html(header_template, binding)

      @footer_advice = generate_html(footer_template, binding)
    end

    private def full_year_solar_pv_sheffield_estimates
      text = %{
        <p>
        Energy Sparks estimates that your solar panels produce about
          <%= annual_solar_pv_kwh_html %> of electricity each year,
          <%= annual_solar_pv_consumed_onsite_kwh_html %> is consumed by the school,
          reducing the schools electricity consumption from the National Electricity Grid by
          <%= annual_saving_from_solar_pv_percent_html %>. In addition the school
          exports about <%= annual_exported_solar_pv_kwh_html %>
          when the solar panels produce more electricity than the school needs.
        </p>
      }.gsub(/^  /, '')
      ERB.new(text).result(binding)
    end

    private def partial_year_solar_pv_sheffield_estimates
      text = %{
        <p>
        Energy Sparks estimates that your solar panels produced about
          <%= annual_solar_pv_kwh_html %> of electricity since they
          were installed in <%= pv_util.install_month_year_text %>,
          <%= annual_solar_pv_consumed_onsite_kwh_html %> was consumed by the school,
          reducing the schools electricity consumption from the National Electricity Grid by
          <%= annual_saving_from_solar_pv_percent_html %>. In addition the school
          exported about <%= annual_exported_solar_pv_kwh_html %>
          when the solar panels produce more electricity than the school needs.
        </p>
      }.gsub(/^  /, '')
      ERB.new(text).result(binding)
    end

    private def full_year_solar_pv_metered
      text = %{
        <p>
        Your solar panels produced
          <%= annual_solar_pv_kwh_html %> of electricity last year,
          <%= annual_solar_pv_consumed_onsite_kwh_html %> was consumed by the school,
          reducing the schools electricity consumption from the National Electricity Grid by
          <%= annual_saving_from_solar_pv_percent_html %>. In addition the school
          exported about <%= annual_exported_solar_pv_kwh_html %>
          when the solar panels produced more electricity than the school consumed.
        </p>
      }.gsub(/^  /, '')
      ERB.new(text).result(binding)
    end

    private def partial_year_solar_pv_metered
      text = %{
        <p>
        Your solar panels produced
          <%= annual_solar_pv_kwh_html %> of electricity since they
          were installed in <%= pv_util.install_month_year_text %>,
          <%= annual_solar_pv_consumed_onsite_kwh_html %> was consumed by the school,
          reducing the schools electricity consumption from the National Electricity Grid by
          <%= annual_saving_from_solar_pv_percent_html %>. In addition the school
          exported about <%= annual_exported_solar_pv_kwh_html %>
          when the solar panels produced more electricity than the school consumed.
        </p>
      }.gsub(/^  /, '')
      ERB.new(text).result(binding)
    end

    private def annual_solar_pv_commentary
      if @school.sheffield_simulated_solar_pv_panels?
        if pv_util.full_years_solar_installation?
          full_year_solar_pv_sheffield_estimates
        else
          partial_year_solar_pv_sheffield_estimates
        end
      else
        if pv_util.full_years_solar_installation?
          full_year_solar_pv_metered
        else
          partial_year_solar_pv_metered
        end
      end
    end

    private def header_template
      %{
        <%= @body_start %>
          <p>
            Your school has solar photovoltaic (PV) panels which produce electricity
            from sunlight. These panels reduce your school's electricity consumption
            from the National Electricity Grid and reduce your school's carbon
            emissions, as electricity produced from solar panels produces very little
            carbon. Solar panels also save your school money.
          </p>
          <%= annual_solar_pv_commentary %>
          <p>
            The chart below shows your school&apos;s electricity consumption over the last
            year and, how much of this consumption is supplied by your solar PV panels
            and consumed onsite, and how much is exported to the National Electricity
            Grid on days when the panels are producing more electricity than the school
            needs:
          </p>
        <%= @body_end %>
      }.gsub(/^  /, '')
    end

    private def footer_template
      %{
        <%= @body_start %>
          <p>
            The line on the chart represents the 'average solar irradiance' - which is
            a measure of how bright the sun was during the month.
          </p>
          <p>
            <strong>Question 1</strong>
            : What time of year does your school's solar PV panels produce the most
            electricity? Why do you think this is?
          </p>
          <p>
            <strong>Question 2</strong>
            : It's important when installing solar PV panels to face them in a
            direction which generates the most electricity? Which compass direction do
            your panels face (north, east, south, or west)? Is this a good direction to
            face to get the maximum sunlight? Think about how the sun travels around
            the sky during the day, and it's elevation (how high in the sky it is)?
          </p>
        <%= @body_end %>
      }.gsub(/^  /, '')
    end
  end

  class SolarPVVersusIrradianceLastYearOverviewAdvice < SolarPVVersusIrradianceLastYearAdvice
    private def footer_template
      %{
        <%= @body_start %>
          <p>
            The table below provides information on your electricity consumption and
            electricity from your school panels <%= period_introduction %>:
          </p>
          <p>
            <%= formatted_summary_table_html %>
          </p>
        <%= @body_end %>
      }.gsub(/^  /, '')
    end
  end

  class SolarPVLast7Days < SolarPVAdviceBase
    def generate_advice
      header_template = %{
        <%= @body_start %>
          <p>
            This chart shows the last 7 days electricity consumption at your school.
            The line shows how sunny it was, and the bars your school&apos;s electricity consumption.
          </p>
        <%= @body_end %>
      }.gsub(/^  /, '')
  
      @header_advice = generate_html(header_template, binding)
  
      footer_template = %{
        <%= @body_start %>
          <p>
            <strong>Question 3</strong>
            : At what time of day do your solar PV panels provide the most electricity
            for your school?
          </p>
          <p>
            <strong>Question 4</strong>
            : Does your school export electricity to the National Electricity Grid? On
            what days of the week does this happen? Why do you think this is?
          </p>
          <h2>
            Summary of electricity usage for the last year:
          </h2>
          <p>
            The table below provides information on your electricity consumption and
            electricity from your school panels <%= period_introduction %>:
          </p>
          <p>
            <%= formatted_summary_table_html %>
          </p>
          <p>
            The school should save costs through having solar PV panels, how much will
            depend on whether the school own's its own panels or a third party energy
            company owns the panels and provides the electricity for free or at a lower
            cost:
          </p>
          <ul>
            <li>
              Panels owned by the school:
            </li>
            <ul>
              <li>
                In general, the school will save from the free electricity it is
                consuming from the panels, about <%= annual_solar_pv_consumed_onsite_£_html %>
                (&#163;<%= BenchmarkMetrics.pricing.electricity_price %>/kWh x
                  <%= annual_solar_pv_consumed_onsite_kwh_html %>)
              </li>
              <li>
                It will also gain about <%= annual_exported_solar_pv_£_html %> from exported electricity
                (&#163;<%= BenchmarkMetrics.pricing.solar_export_price %>/kWh)
              </li>
              <li>
                If the panels were installed before April 2019 it might also gain from the
                government subsidy called 'feed-in-tariff'. The amount of the feed in tariff
                will depend on when the panels were installed and is typically in the range
                5p/kWh to 40 p/kWh x the total 'Photovoltaic production' of
                <%= annual_solar_pv_kwh_html %>, each year
              </li>
            </ul>
          </ul>
          <ul>
            <li>
              Panels owned by a third party:
            </li>
            <ul>
              <li>
                Generally, this saving is just the 'Self-consumption' (<%= annual_solar_pv_consumed_onsite_kwh_html %>)
                times the difference (discount) between the cost of the mains electricity, and how
                much the third party is charging for electricity per kWh.
              </li>
            </ul>
          </ul>
          <p>
            In all cases the school's carbon emissions will be reduced by having solar
            panels. For your school this is approximately <%= annual_co2_saving_kg_html %>.
          </p>
          <p>
            <strong>Question 5</strong>
            Can you calculate how much annual cost savings your school gets from having solar PV panels?
          </p>
          <h2>
            Answers to questions:
          </h2>
          <p>
            1. Solar PV panels produce most electricity in the middle of summer when it
            is sunniest, and least in the winter when there isn't much sun
          </p>
          <p>
            2. South facing panels are generally best because we are in the
            northern hemisphere we get the most sun when facing south
          </p>
          <p>
            3. Solar panels generally produce the most electricity in the middle of the
            day when the sun is brightest. If it is cloudy then they will produce less.
          </p>
          <p>
            4. Solar PV panels generally export the most electricity at weekends and
            during holidays, when there is no one in the school and the panels are
            producing more electricity than the school is consuming (from appliances
            like computers which have been left on). Unless the school has a very large
            number of panels its unlikely that these panels will produce more
            electricity than the school is consuming during a school day when the
            building is in use.
          </p>
          <p>
            5. The answer to this question will depend on whether your school owns the panels
            (the value of your feed-in-tariff), or the cost of solar electricity
            charged by the third party.
        </p>
        <%= @body_end %>
      }.gsub(/^  /, '')
  
      @footer_advice = generate_html(footer_template, binding)
    end
  end

end
