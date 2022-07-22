class AdviceGasThermostaticControl  < AdviceBoilerHeatingBase
  include Logging

  def enough_data
    # aggregate_meter.amr_data.days > 364 && valid_model? ? :enough : :not_enough
    valid_model? ? :enough : :not_enough
  end

  def raw_content(user_type: nil)
    thermostatic_control(user_type: user_type) +
    diurnal_control(user_type: user_type) +
    cusum(user_type: user_type)
  end

  private

  def heating_model(model_type: :simple_regression_temperature)
    # use simple_regression_temperature rather than best model for the explanation
    # otherwise the chart is too complicated for most
    # users to understand if the thermally massive model is used
    @heating_model ||= calculate_heating_model(model_type: model_type)
  end

  def r2
    heating_model.average_heating_school_day_r2
  end

  def winter_heating_samples
    heating_model.winter_heating_samples
  end

  def r2_html
    FormatEnergyUnit.format(:r2, r2, :html)
  end

  def r2_adjective
    AnalyseHeatingAndHotWater::HeatingModel.r2_rating_adjective(r2)
  end

  def insulation_hotwater_heat_loss_estimate_kwh
    loss_kwh, percent_loss = heating_model.hot_water_poor_insulation_cost_kwh(one_year_before_last_meter_date, last_meter_date)
    loss_kwh
  end

  def annual_loss_£_html
    FormatEnergyUnit.format(:£, insulation_hotwater_heat_loss_estimate_kwh, :html)
  end

  def annual_loss_kwh_html
    FormatEnergyUnit.format(:kwh, insulation_hotwater_heat_loss_estimate_kwh, :html)
  end

  def a
    heating_model.average_heating_school_day_a
  end

  def b
    heating_model.average_heating_school_day_b
  end

  def predicted_kwh(temperature)
    a + b * temperature
  end

  def base_temperature
    heating_model.average_base_temperature
  end

  def thermostatic_control(user_type: nil)
    charts_and_html = [
      { type: :html,        content: title },
      { type: :html,        content: intro_schools_r2 },
      { type: :html,        content: why_thermostatic_control_is_important },
      { type: :html,        content: reasons_for_poor_thermostatic_control },
      { type: :chart_name,  content: :thermostatic_up_to_1_year },
      { type: :html,        content: chart_explanation },
      { type: :html,        content: hot_water_losses },
      { type: :html,        content: calculate_theoretical_daily_consumption_html },
      

      { type: :html,        content: how_to_improve_thermostatic_control },
      { type: :html,        content: further_reading } 
    ]

    charts_and_html
  end

  def title
    %q(
      <h2>Thermostatic Control</h2>
    )
  end

  def intro_schools_r2
    text = %{
      <p>
        The thermostatic control at your school is <%= r2_adjective %> (R<sup>2</sup> = <%= r2_html %>).
      </p>
    }

    ERB.new(text).result(binding)
  end

  def why_thermostatic_control_is_important
    %q(
      <h2>Why thermostatic control is important</h2>

      <p>
        A building with good thermostatic control means
        the heating system brings the temperature of the
        building up to the set temperature, and then maintains
        it at a constant level. The heating required and
        therefore gas consumption should vary linearly with
        how cold it is outside i.e. the colder it is outside
        the higher the gas consumption for heating.
      </p>

      <p>
        The heating system can then adjust for internal heat
        gains due to people, electrical equipment and sunshine
        warming the building. It can also adjust for losses due
        to ventilation. Poor thermostatic control is likely to
        cause poor thermal comfort (occupants feel too hot or too cold),
        and the thermal comfort is then often maintained by leaving
        windows open leading to excessive gas consumption and carbon emissions.
      </p>
    )
  end

  def reasons_for_poor_thermostatic_control
    %q(
      <h2>Reasons for poor thermostatic control</h2>

      <p>
        Unfortunately, many schools have poor thermostatic control.
        This can be due to poorly located boiler thermostats.
        A common location for a thermostat in schools is
        in the school hall or entrance lobby whose heating,
        internal gains and heat losses are not representative
        of the building as a whole, and particularly classrooms.
        Halls are often poorly insulated with few radiators
        which means they never get up to temperature, causing
        the boiler controller to run the boiler constantly which
        causes the better insulated classrooms to overheat,
        and more gas consumption than necessary.
      </p>

      <p>
        Poor thermostatic control can also be due to a lack
        of thermostatic controls in individual rooms,
        which leads to windows being opened to compensate.
        If it’s difficult to provide local thermostatic control
        in each room, for example Thermostatic Radiator Valves (TRVs)
        can’t be installed on radiators you could ask your boiler
        engineers whether
        <strong>’weather compensation’<!╌ technical term don't translate ╌></strong>,
        which reduces the temperature of the circulating central
        heating water in milder weather can be configured for your boiler as an alternative.
      </p>
    )
  end

  def chart_explanation
    text = %q(
      <p>
        The scatter chart above shows a thermostatic analysis
        of your school&apos;s heating system. The y axis shows
        the energy consumption in kWh on any given day.
        The x axis is the outside temperature.
      </p>

      <p>
        If the heating has good thermostatic control then
        the points at the top of chart when the heating
        is on should be close to
        the trend line. This is because the amount of heating
        required on a single day is linearly proportional to the
        difference between the inside and outside temperature,
        and any variation from the trend line would suggest
        thermostatic control isn&apos;t working too well.
      </p>

      <p>
        R<sup>2</sup> is a measure of how close to the trendline the daily
        heating values are. At your school this is <%= r2_html %>
        which is <strong><%= r2_adjective %></strong>,
        a value of 1.0 is perfect,
        0.0 indicated no relationship between how cold
        it is outside and how much gas is consumed which
        would be very bad for the school’s carbon emissions
        and running costs.
      </p>

      <p>
        Two sets of data are provided on the chart.
        The points associated with the group at the top
        of the chart are those for winter school day heating.
        As it gets warmer the daily gas consumption drops.
      </p>
    )

    ERB.new(text).result(binding)
  end

  def hot_water_losses
    text = %q(
      <% if meter.heating_only? %>
        <p>
          The second set of data at the bottom of the chart
          is for gas consumption in the summer when the heating
          is not on; typically, this is from hot water and
          kitchen consumption. The slope of this line is often
          an indication of how well insulated the hot water system is;
          if the consumption increases as it gets colder it
            suggests a lack of insulation.
            An estimate of this loss across the last year is
            <%= annual_loss_£_html %> (<%= annual_loss_kwh_html %>).
        </p>
      <% end %>
    )

    ERB.new(text).result(binding)
  end

  def how_to_improve_thermostatic_control
    %q(
      <h2>How to improve your school’s thermostatic control</h2>

      <p>
        Measures for improving thermostatic control:
        <ul>
          <li>
            Check the siting of the boiler thermostats
            – halls and corridors are not good locations
          </li>
          <li>
            Check the thermostat settings or TRV radiator
            settings every two weeks in the winter to make
            sure they haven’t been turned up – they should
            be set to keep classrooms at a recommended 18C
          </li>
          <li>
            Configure
            <strong>’weather compensation’<!╌ technical term don't translate ╌></strong>
            on your boiler (ask your boiler engineers)
          </li>
        </ul>
      </p>
    )
  end

  def calculate_theoretical_daily_consumption_html
    text = %q(
      <h2>How to calculate a theoretical daily gas consumption using the model</h2>

      <p>
        For energy experts, the formula which defines the trend line is very interesting.
        It predicts how the gas consumption varies with outside temperature.
      </p>

      <p>In the example above the formula for heating is:</p>

      <blockquote>predicted_heating_requirement = <%= b.round(1) %> * outside_temperature + <%= a.round(0) %></blockquote>
      
      <p>
        So for your school if the average outside temperature is 12C
        the predicted gas consumption for the school would be
        <%= b.round(1) %> * 12.0 + <%= a.round(0) %> = <%= predicted_kwh(12.0).round(0) %> kWh for the day.
        Whereas if the outside temperature was colder at 4C the gas consumption would be
        <%= b.round(1) %> * 4.0 + <%= a.round(0) %> = <%= predicted_kwh(4.0).round(0) %> kWh.
        See if you can read these values off the trend line of the graph above
        (temperatures of 12C and 4C on the x axis and the answer - the predicted daily gas consumption on the y-axis).
      </p>
    )
    ERB.new(text).result(binding)
  end

  def further_reading
    %q(
      <h2>Further reading</h2>

      <p>
        <ul>
          <li>
            <a href="https://blog.minitab.com/en/adventures-in-statistics-2/regression-analysis-how-do-i-interpret-r-squared-and-assess-the-goodness-of-fit" target ="_blank">Explanation of r2</a>
          </li>
          <li>
          <a href="https://www.sustainabilityexchange.ac.uk/files/degree_days_for_energy_management_carbon_trust.pdf" target ="_blank">An explanation of thermostatic control</a>
             (versus degree days - which is similar to
              the way Energy Sparks looks at thermostatic control
              but we use temperature instead of degree days). 
          </li>
        </ul>
      </p>
    )
  end

  def diurnal_control(user_type: nil)
    charts_and_html = [
      { type: :html,        content: diurnal_control_intro },
      { type: :chart_name,  content: :thermostatic_control_large_diurnal_range },
      { type: :html,        content: diurnal_control_chart_change_date },
    ]

    charts_and_html
  end

  def diurnal_control_intro
    %q(
      <h2>Using days with large diurnal range to understand thermostatic control</h2>

      <p>
        An alternative way of looking at the thermostatic control is to
        look at whether a school&apos;s gas consumption changes on a day when
        the outside temperature changes significantly. It is common,
        particularly in Spring for outside temperatures to increase by
        more than 10C during the day (called a large diurnal temperature range,
        typically caused by cold ground temperatures after the winter reducing
        overnight temperatures, and warm Spring sunshine during the day).
      </ p> 

      <p>
        In theory if outside temperatures rise by 10C, then the heating loss
        through a building&apos;s fabric (walls, windows etc.) will more than
        halve (as the heat loss is proportional to the difference between outside
        and inside temperatures). If the school has good thermostatic control
        then you would expect so see a similar drop in gas consumption over the course of the day.
      </p>

      <p>
        The chart below shows recent example winter days with a large diurnal range:
      </p>
    )
  end

  def diurnal_control_chart_change_date
    %q(
      <p>
        You can click on the &apos;Explore&apos; buttons on the chart
        e.g. &apos;Back 1 day with large diurnal range&apos; to examine other
        days.
      </p>
    )
  end

  def cusum(user_type: nil)
    return '' unless ContentBase.analytics_user?(user_type)

    charts_and_html = [
      { type: :html,        content: '<h2>Cusum chart (analytics user only)</h2>' },
      { type: :chart_name,  content: :cusum },
    ]

    charts_and_html
  end
end
