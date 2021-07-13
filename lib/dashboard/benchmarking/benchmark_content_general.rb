require_relative './benchmark_no_text_mixin.rb'
module Benchmarking
  CAVEAT_TEXT = {
    es_doesnt_have_all_meter_data: %q(
      <p>
        The table provides the information in more detail.
        Energy Sparks doesn&apos;t have a full set of meter data
        for some schools, for example rural schools with biomass or oil boilers,
        so this comparison might not be relevant for all schools. The comparison
        excludes the benefit of any solar PV which might be installed - so looks
        at energy consumption only.
      </p>
    ),
    es_data_not_in_sync: %q(
      <p>
        The gas, electricity and storage heater costs are all using the latest
        data. The total might not be the sum of these 3 in the circumstance
        where one of the meter's data is out of date, and the total then covers the
        most recent year where all data is available to us on all the underlying
        meters, and hence will cover the period of the most out of date of the
        underlying meters.
      </p>
    ),
    es_per_pupil_v_per_floor_area: %q(
      <p>
          Generally, per pupil benchmarks are appropriate for electricity
          (should be proportional to the appliances e.g. ICT in use),
          but per floor area benchmarks are more appropriate for gas (size of
          building which needs heating). Overall, <u>energy</u> use comparison
          on a per pupil basis is probably more appropriate than on a per
          floor area basis, but this analysis can be useful in some circumstances.
      </p>
    ),
    es_exclude_storage_heaters_and_solar_pv: %q(
      <p>
        This breakdown excludes electricity consumed by storage heaters and
        solar PV.
      </p>
    ),
    comparison_with_previous_period_infinite: %q(
      <p>
        An infinite value indicates the consumption in the first period was zero.
      </p>
    ),
    es_sources_of_baseload_electricity_consumption: %q(
      <p>
        Consumers of out of hours electricity include
        <ul>
          <li>
            Equipment left on rather than being turned off, including
            photocopiers and ICT equipment
          </li>
          <li>
            ICT servers - can be inefficient, newer ones can often payback their
            capital costs in electricity savings within a few years, see our
            <a href="https://blog.energysparks.uk/wp-content/uploads/2019/11/Energy-Sparks-Case-Study-4-Trinity-School-ICT-Servers.pdf" target ="_blank">case study</a>
            on this
          </li>
          <li>
            Security lighting - this can be reduced by using PIR movement detectors
            - often better for security and by moving to more efficient LED lighting
          </li>
          <li>
            Fridges and freezers, particularly inefficient commercial kitchen appliances, which if
            replaced can provide a very short payback on investment (see 
            our <a href="https://cdn.energysparks.uk/static-assets/Energy_Sparks_Case_Study_1_-_Freshford_Freezer-b6f1a27e010c019004aa72929a9f8663c85ecb0d4723f0fe4de1798b26e6afde.pdf" target ="_blank">case study</a> on this).
          </li>
          <li>
            Hot water heaters and boilers left on outside school hours - installing a timer or getting
            the caretaker to switch these off when closing the school at night or on a Friday can
            make a big difference
          </li>
        </ul>
      <p>
    )
  }
  #=======================================================================================
  class BenchmarkContentEnergyPerPupil < BenchmarkContentBase
    include BenchmarkingNoTextMixin
    private def introduction_text
      text = %q(
        <p>
          This benchmark compares the energy consumed per pupil each year in &pound;.
        </p>
        <p>
          This benchmark is best used for economic comparisons. 
          <%= CAVEAT_TEXT[:es_per_pupil_v_per_floor_area] %>
        </p>
      )
      ERB.new(text).result(binding)
    end
    private def table_introduction_text
      CAVEAT_TEXT[:es_doesnt_have_all_meter_data]
    end
  end
  #=======================================================================================
  class BenchmarkContentTotalAnnualEnergy < BenchmarkContentBase
    include BenchmarkingNoTextMixin
    private def introduction_text
      %q(
        <p>
          This benchmark shows how much each school is spending on energy each year.
        </p>
      )
    end
    private def table_introduction_text
      CAVEAT_TEXT[:es_doesnt_have_all_meter_data]
    end
    protected def table_interpretation_text
      CAVEAT_TEXT[:es_data_not_in_sync]
    end
  end
  #=======================================================================================
  class BenchmarkContentElectricityPerPupil < BenchmarkContentBase
    include BenchmarkingNoTextMixin
    private def introduction_text
      %q(
        <p>
          This benchmark compares the electricity consumed per pupil each year,
          in &pound;.
        </p>
        <p>
          A realistic target for primary schools is to use less than
          &pound;20 per pupil per year, for middle schools &pound;30
          and for secondaries &pound;40. There  shouldn't be a
          significant difference between schools as all schools
          need to use roughly the same amount of ICT equipment,
          lighting and refrigeration per pupil. Exceptions might
          be schools with swimming pools or sports flood lighting
          which can significantly increase demand.
        </p>
        <p>
          To meet these targets the biggest reductions
          can often be achieved by focussing on &apos;baseload&apos;
          ensuring equipment is turned off out of hours, and that the
          equipment which is left on is as efficient as possible. Energy Sparks
          has separate comparisons and analysis for baseload.
        </p>
        <p>
          The data excludes storage heaters which are reported elsewhere
          under the &apos;heating&apos; benchmarks.
        </p>
      )
    end
  end
  #=======================================================================================
  class BenchmarkContentChangeInAnnualElectricityConsumption < BenchmarkContentBase
    include BenchmarkingNoTextMixin
    private def introduction_text
      %q(
        <p>
          This benchmark shows the change in electricity consumption between
          this year and last year, excluding solar PV and storage heaters.
        </p>
        <p>
          Schools should be aiming to reduce their electricity consumption by
          about 5% per year because most equipment used by schools is getting
          more efficient, for example a desktop computer might use 150W, a laptop
          20W and a tablet 2W. Switching from using desktops to tablets reduces
          their electricity consumption by a factor of 75. LED lighting can be
          2 to 3 times for efficient than older florescent lighting.
        </p>
        <p>
          To make a significant contribution to mitigating climate
          change schools should really be aiming to reduce their electricity
          consumption by 10% year on year to meet the UK&apos;s climate change obligations
          - something which is easily achievable
          through a mixture of behavioural change and tactical investment in
          more efficient equipment.
        </p>
        <p>
          An increase in electricity consumption, unless there has been a significant
          increase in pupil numbers is inexcusable if a school is planning on contributing
          to reducing global carbon emissions.
        </p>
      )
    end
  end
  #=======================================================================================
  class BenchmarkContentElectricityOutOfHoursUsage < BenchmarkContentBase
    include BenchmarkingNoTextMixin
    private def introduction_text
      text = %q(
        <p>
          This chart shows the breakdown of when schools are using electricity
          - school day open: when the school is open to pupils and staff,
          school day closed: when the school is closed to pupils and staff overnight,
          weekends and evenings.
        </p>
        <p>
          Most schools are unoccupied for about 85% of the year;
          between 5:00pm and 7:30am on school days, at weekends
          and during holidays. Focussing on reducing out of hours
          usage; turning appliances off, installing efficient
          appliances often provides schools with a cost-efficient
          way of reducing their overall consumption.
        </p>
        <p>
          Schools should aim to reduce their out of hours usage
          below 25% of annual consumption. In comparing schools,
          it might be helpful for you to look at the 2 additional
          benchmarks on baseload (out of hours power consumption)
          that we provide as it might give you more information
          on a school&apos;s out of hours consumption.
        </p>
        <%= CAVEAT_TEXT[:es_exclude_storage_heaters_and_solar_pv] %>
      )
      ERB.new(text).result(binding)
    end
  end
  #=======================================================================================
  class BenchmarkContentChangeInBaseloadSinceLastYear < BenchmarkContentBase
    include BenchmarkingNoTextMixin
    private def introduction_text
      text = %q(
        <p>
          This benchmark compares a school&apos;s current baseload (electricity
          consumed when the school is closed) with that of the average
          of the last year. Schools should be aiming to reduce baseload over time
          and not increase it as equipment and lighting has become significantly
          more efficient over the last few years. Any increase should be tracked
          down as soon as it is discovered. Energy Sparks can be configured
          to send you an alert via an email or a text message if it detects
          this has happened.
        </p>
        <p>
          A 1 kW increase in baseload is equivalent to an increase in
          annual electricity costs of &pound;1,100.
        </p>
        <%= CAVEAT_TEXT[:es_exclude_storage_heaters_and_solar_pv] %>
      )
      ERB.new(text).result(binding)
    end
  end
  #=======================================================================================
  class BenchmarkContentBaseloadPerPupil < BenchmarkContentBase
    include BenchmarkingNoTextMixin
    private def introduction_text
      text = %q(
        <p>
          A school&apos;s baseload is the power it consumes out of hours when
          the school is unoccupied.
        </p>
        <p>
          This is one of the most useful benchmarks for understanding
          a school&apos;s electricity use, as half of most schools&apos;
          electricity is consumed out of hours, reducing the baseload will have a big
          impact on overall electricity consumption.
        </p>
        <p>
          All schools should aim to reduce their electricity baseload per pupil
          to that of the best schools. Schools perform roughly the same function
          so should be able to achieve similar electricity consumption
          particularly out of hours.
        </p>
        <%= CAVEAT_TEXT[:es_sources_of_baseload_electricity_consumption ] %>
        <%= CAVEAT_TEXT[:es_exclude_storage_heaters_and_solar_pv] %>
      )
      ERB.new(text).result(binding)
    end
  end

  #=======================================================================================
  class BenchmarkSeasonalBaseloadVariation < BenchmarkContentBase
    include BenchmarkingNoTextMixin
    private def introduction_text
      text = %q(
        <p>
          A school&apos;s baseload is the power it consumes out of hours when
          the school is unoccupied.
        </p>
        <p>
          In general, in general with very few exceptions the baseload in the winter
          should be very slimiar to the summer. In practice many school accidently
          leave electrically powered heating-related equipment on overnight whe
          the school is unoccupied.
        </p>
        <p>
          Identifying and turning off or better timing such equipment is a quick way
          of saving electricity and costs.
        </p>
        <%= CAVEAT_TEXT[:es_sources_of_baseload_electricity_consumption ] %>
        <%= CAVEAT_TEXT[:es_exclude_storage_heaters_and_solar_pv] %>
      )
      ERB.new(text).result(binding)
    end
  end

  #=======================================================================================
  class BenchmarkWeekdayBaseloadVariation < BenchmarkContentBase
    include BenchmarkingNoTextMixin
    private def introduction_text
      text = %q(
        <p>
          A school&apos;s baseload is the power it consumes out of hours when
          the school is unoccupied.
        </p>
        <p>
          In general, in general with very few exceptions the baseload shouldn&apos;t
          vary between days of the week and even between weekdays and weekends.
        </p>
        <p>
          If there is a big variation it often suggests that there is an opportunity
          to reduce baseload by find out what is causing the baseload to be higher on
          certain days of the week than others, and switch off whatever is causing
          the difference.
        </p>
        <%= CAVEAT_TEXT[:es_sources_of_baseload_electricity_consumption ] %>
        <%= CAVEAT_TEXT[:es_exclude_storage_heaters_and_solar_pv] %>
      )
      ERB.new(text).result(binding)
    end
  end

  #=======================================================================================  
  class BenchmarkContentPeakElectricityPerFloorArea < BenchmarkContentBase
    include BenchmarkingNoTextMixin
    private def introduction_text
      %q(
        <p>
          This comparison shows the peak daily school power consumption per floor area.
          High values compared with other schools might suggest inefficient lighting,
          appliances or kitchen equipment. The peaks generally occur during the middle
          of the day. Energy Sparks allows you to drill down to individual school day usage
          to better understand the intraday characteristics of a school&apos;s electricity
          consumption.
        </p>
        <p>
          If a school&apos;s electricity consumption is high compared with
          other schools is probably warrants further investigation. There might be
          simple low-cost remedies like turning lighting off when it is bright outside,
          or better management of appliances in a school&apos;s kitchen. Other measures
          like installing LED lighting might require investment.
        </p>
        <p>
          LED lighting for example can consume as little as 4W/m<sup>2</sup>, whereas older
          less efficient lighting can consume up to 12W/m<sup>2</sup>.
        </p>
      )
    end
  end
    #=======================================================================================  
    class BenchmarkContentSolarPVBenefit < BenchmarkContentBase
      include BenchmarkingNoTextMixin
      private def introduction_text
        %q(
          <p>
            The comparison below shows the benefit of installing solar PV panels
            at schools which don't already have solar PV panels. This analysis
            is based on using half hourly electricity consumption at
            each school over the last year and combining it with local half hourly
            solar pv data to work out the benefit of installing solar panels.
            Further detail is provided if you drilldown to a school&apos;s individual
            analysis - where a range of different scenarios of different numbers
            of panels is presented.
          </p>
        )
      end
    end
  #=======================================================================================
  class BenchmarkContentSummerHolidayBaseloadAnalysis < BenchmarkContentBase
    include BenchmarkingNoTextMixin
    private def introduction_text
      text = %q(
        <p>
          This analysis attempts to analyse whether a school
          has reduced its electricity consumption during the
          summer holidays.
        </p>
        <p>
          IIt&apos;s a useful way of
          determining the efficiency appliances which have been switched off.
          The school will need to know which appliances have been turned off
          in order for you to understand what contributed to the reduction.
        </p>
        <p>
          The most common reduction is due to some or all of kitchen fridges and
          freezers being turned off over the summer.
          Our <a href="https://cdn.energysparks.uk/static-assets/Energy_Sparks_Case_Study_1_-_Freshford_Freezer-b6f1a27e010c019004aa72929a9f8663c85ecb0d4723f0fe4de1798b26e6afde.pdf" target ="_blank">case study</a>
          on this demonstrates that it is possible to get a short return on investment
          replacing old inefficient refrigeration with more efficient modern equipment.
          It is also good practice to empty and turn off refrigeration over the summer holidays
          - Energy Sparks can be configured to send an &apos;alert&apos; via email or text
          just before holidays to remind schools to do this.
        </p>
        <p>
          To further investigate the issue it is worth installing appliance monitors
          to establish accurately how inefficient equipment is, before making a purchasing decision.
          Domestic rather than commercial refrigeration generally offers much better value
          and efficiency.
        </p>
      )
      ERB.new(text).result(binding)
    end
    protected def table_introduction_text
      %q( 
        <p>
          Large domestic A++ rated fridges
          and freezers typically use £40 of electricity per year each.
        </p>
        <p>
          This breakdown excludes electricity consumed by storage heaters and solar PV.
        </p>
       )
    end
  end
  #=======================================================================================
  class BenchmarkContentHeatingPerFloorArea < BenchmarkContentBase
    include BenchmarkingNoTextMixin
    private def introduction_text
      %q(
        <p>
          This benchmark compares the gas and storage heater costs
          per floor area (m<sup>2</sup>) each year, in &pound;.
        </p>
        <p>
          The benchmark is adjusted for regional temperatures over the
          last year, so that for example
          schools in Scotland are compared on the same terms as schools in the
          warmer south west of England.
        </p>
        <p>
          For schools heated by gas, the cost includes gas used for hot water and
          by the school kitchen.
        </p>
        <p>
          More modern schools should have lower consumption, however, a well-managed
          Victorian school which turns its heating off during holidays and weekends
          often has lower heating and hot water consumption than more modern schools.
        </p>
      )
    end
    protected def table_introduction_text
      %q( 
        <p>
          Schools with negative 'Saving if matched exemplar school' have
          heating consumption below that of the best schools, which is good. For
          schools with storage heaters, heating costs are calculated using 
          electricity tariff prices (differential/economy-7 if schools is on such a tariff) versus
          costs of exemplar schools using gas heating or an air source heat pump.
        </p>
       )
    end
  end
  #=======================================================================================
  class BenchmarkContentChangeInAnnualHeatingConsumption < BenchmarkContentBase
    include BenchmarkingNoTextMixin
    private def introduction_text
      %q(
        <p>
          This benchmark shows the change in the gas and storage heater costs
          from last year to this year.
        </p>
        <p>
          Schools should aim to reduce their heating and hot water costs
          each year through better control of boilers and storage radiators;
          making sure they are switched off when unoccupied. Better management
          can typically reduce these costs by between 15% and 50%, at little
          or no cost to a school. Even something as simple as turning the thermostat
          down 1C can lead to a significant reduction in costs.
        </p>
        <p>
          Upgrading boilers, switching from gas based circulatory hot water systems
          to point of use electric hot water, and installing boiler optimum start control
          and weather compensation which require investment will reduce costs further.
        </p>
      )
    end
  end
  #=======================================================================================
  class BenchmarkContentGasOutOfHoursUsage < BenchmarkContentBase
    include BenchmarkingNoTextMixin
    private def introduction_text
      %q(
        <p>
          This chart shows the breakdown of when schools are using gas
          - school day open: when the school is open to pupils and staff,
          school day closed: when the school is closed to pupils and
          staff overnight, weekends and evenings. 
        </p>
        <p>
          Most schools are unoccupied for about 85% of the year;
          between 5:00pm and 7:30am on school days, at weekends
          and during holidays. Focussing on reducing out of hours
          usage; turning heating and hot water systems off out of hours
          provides schools with a cost-efficient
          way of reducing their overall consumption.
        </p>
        <p>
          Schools should aim to reduce their out of hours usage
          below 35% of annual consumption. Implementing a policy to reduce
          weekend and holiday use, and ensuring the boiler doesn&apos;t
          start too early in the morning should allow most school's
          to meet this target with no capital investment costs. It shouldn&apos;t
          be necessary to leave heating on during winter holidays and weekends if
          the boilers frost protection functions have been configured correctly
          to come on only when necessary.
        </p>
        <p>
          You can get Energy Sparks to send you a reminder (an &apos;alert&apos;) just before holidays
          to turn your heating off.
        </p>
      )
    end
  end
  #=======================================================================================  
  class BenchmarkContentStorageHeaterOutOfHoursUsage < BenchmarkContentBase
    include BenchmarkingNoTextMixin
    private def introduction_text
      %q(
        <p>
          Storage heaters consume electricity and store heat overnight when
          electricity is cheaper (assuming the school is on an &apos;economy 7&apos;
          type differential tariff) and releases the heat during the day.
        </p>
        <p>
          Ensuring heating is turned off over the weekend by installing a 7 day
          timer can provide very short paybacks - 16 weeks in this
          <a href="https://cdn-test.energysparks.uk/static-assets/Energy_Sparks_Case_Study_3_-_Stanton_Drew_Storage_Heaters-f124cfe069b2746ab175f139c09eee70fcb558d5604be86811c70fedd67a7a6d.pdf" target ="_blank">case study</a>.
          Turning off the heaters or turning them down as low as possible to avoid frost damage
          can save during holidays.
          We recommend you set a school policy for this. Energy Sparks
          can provide accurate estimates of the benefits of installing 7-day timers, or
          switching off during holidays if you drilldown to an individual school&apos;s analysis pages.
        </p>
        <p>
          You can get Energy Sparks to send you a reminder (an &apos;alert&apos;) just before holidays
          to turn your heating off.
        </p>
      )
    end
  end
  #=======================================================================================  
  class BenchmarkContentThermostaticSensitivity < BenchmarkContentBase
    include BenchmarkingNoTextMixin
    private def introduction_text
      %q(
        <p>
          This chart and table indicate the benefit at each school
          of reducing the thermostats temperature setting per 1C
          of reduction.
        </p>
        <p>
          Occasionally this will result in a negative value, which is indicative
          or very poor thermostatic control where the internal mathematics cannot
          make sense of the relationship between the school&apos;s gas consumption and
          outside temperature.
        </p>
      )
    end
  end
  #=======================================================================================  
  class BenchmarkContentLengthOfHeatingSeason < BenchmarkContentBase
    include BenchmarkingNoTextMixin
    private def introduction_text
      %q(
        <p>
          Schools often forget to turn their heating off in warm weather,
          about 10% of schools leave their heating on all summer.
        </p>
        <p>
          The chart and table below show how many days the heating was
          left on in the last year and the potential benefit of switching
          the heating off in warmer weather. Schools should target reducing
          the length of the heating season to below 90 days.
        </p>
        <p>
          You can set up Energy Sparks email or text alerts which will notify
          you if the weather forecast for the coming week suggests you should
          turn off your heating.
        </p>
      )
    end
  end
  #=======================================================================================  
  class BenchmarkContentThermostaticControl < BenchmarkContentBase
    include BenchmarkingNoTextMixin
    private def introduction_text
      %q(
        <p>
          Energy Sparks calculates how good a school&apos;s thermostatic control
          is by calculating a measure called &apos;R2&apos;. The heating consumption
          of a school should be linearly proportional to the outside temperature, the colder
          it is the more energy is required to keep the school warm. The &apos;R2&apos;
          is a measure of how well correlated this heating consumption is with outside
          temperature - the closer to 1.0 the better the control. Any value above 0.8
          is good. If a school has a value below 0.5 it suggests the thermostatic control
          is very poor and there is a limited relationship between the temperature and
          the heating used to keep the school warm.
        </p>
        <p>
          There can be many reasons for this control being poor:
          <ul>
            <li>
              A poorly sited thermostat, for example in a corridor or a hall
            </li>
            <li>
              Poor radiator control, the thermostatic valves (TRVs) on each radiator
              aren&apos;t appropriately set, perhaps set too high, and rather than
              turning them down, occupants of classrooms open windows to reduce
              overheating.
            </li>
          </ul>
        </p>
        <p>
          Poor thermostat control can make a school an uncomfortable place to
          inhabit and expensive to run. It also means a school will see
          less benefit in installing insulation if the heating consumption
          has little relationship to outside temperature and therefore
          heat loss.
        </p>
        <p>
          If a school&apos;s thermostatic control is poor and want to improve it,
          please contact Energy Sparks and we would be happy to provide further advice.
        </p>
      )
    end
  end
  #=======================================================================================  
  class BenchmarkContentHotWaterEfficiency < BenchmarkContentBase
    include BenchmarkingNoTextMixin
    private def introduction_text
      %q(
        <p>
          Hot water in schools is generally provided by a central gas boiler which
          then continuously circulates the hot water in a loop around the school.
          Sometimes these gas-based systems are supplemented by more local
          electrically powered immersion or point of use heaters.
        </p>

        <p>
          The circulatory gas-based systems in schools are generally very inefficient.
          These inefficiencies offer significant cost and carbon emission saving
          opportunities if addressed.
        </p>

        <p>
          These systems are inefficient because they circulate hot water permanently
          in a loop around the school so hot water is immediately available when
          someone turns on a tap rather than having to wait for the hot water to come
          all the way from the boiler room. The circulatory pipework used to do this
          is often poorly insulated and loses heat. Often these types of systems are
          only 15% efficient compared with direct point of use water heaters which
          can be over 90% efficient. Replacing the pipework insulation is generally
          not a cost-efficient investment.
        </p>
        <p>
          Drilling down to an individual school's hot water analysis provides
          more detailed information on how a school can reduce its hot water costs.
        </p>
        <p>
          The charts and table below analyse the efficiency of
          schools&apos; hot water systems and the potential savings from either improving
          the timing control of existing hot water systems or replacing it
          completely with point of use electric hot water systems.
        </p>
      )
    end
  end
  #=======================================================================================
  # 2 sets of charts, tables on one page
  class BenchmarkHeatingComingOnTooEarly < BenchmarkContentBase
    include BenchmarkingNoTextMixin
    private def introduction_text
      %q(
        <p>
          This benchmark shows what time the boilers having been starting
          on average in the last week.
        </p>
        <p>
          Generally, if the weather last week was mild then you might
          expect the heating to be coming on at about 6:30am. In colder
          weather depending on the fabric (insulation, thermal mass) of
          the school you might expect the heating to start earlier at
          perhaps 3:00am. If it&apos;s coming on earlier the school&apos;s boiler
          control probably warrants further investigation.
        </p>
        <p>
          If the boiler is coming on too early remedies include:
          <ul>
            <li>
              Monitoring temperature in the school in the early morning - typically
              available via the school&apos;s BMS or boiler controller, or via temperature
              logger (&pound;20 - or you can borrow one from Energy Sparks)
            </li>
            <li>
              Has the school&apos;s thermostat been correctly located,
              if in a cold poorly insulated hall then
              classrooms might be up to temperature many hours before the hall, so perhaps
              the thermostat could be relocated, or the hall&apos;s thermostat&apos;s settings
              could be lowered (16C or less)?
            </li>
            <li>
              Otherwise consider whether the radiator output is high enough to get the
              school up to temperature quickly? Fan convector radiators should take under
              30 minutes to get a room up to temperature even in cold weather, undersized
              traditional radiators can take hours. Is the flow
              temperature high enough, does the pipework allow adequate distribution of heat,
              do the radiators have adequate output, have their TRVs been set too low for
              the main boiler thermostat?
            </li>
            <li>
                If the boiler&apos;s starting time has been set because school users have
                complained it&apos;s too cold in the morning, consider experimenting
                with the start time. We generally recommend starting the boiler
                2 hours early on a Monday, to give the school more time to heat up
                from the weekend, this may mitigate most of the complaints?
            </li>
            <li>
                If the boiler doesn&apos;t have optimum start control (the controller
                based on internal and external temperatures works out the optimum
                time to start the boiler each morning) consider getting one installed
            </li>
          </ul>
        </p>
      )
    end

    def content(school_ids: nil, filter: nil, user_type: nil)
      content1 = super(school_ids: school_ids, filter: filter)
      content2 = optimum_start_content(school_ids: school_ids, filter: filter)
      content1 + content2
    end

    private
    
    def optimum_start_content(school_ids:, filter:)
      content_manager = Benchmarking::BenchmarkContentManager.new(@asof_date)
      db = @benchmark_manager.benchmark_database
      content_manager.content(db, :optimum_start_analysis, filter: filter)
    end
  end

  #=======================================================================================
  class BenchmarkContentEnergyPerFloorArea < BenchmarkContentBase
    include BenchmarkingNoTextMixin

    private def introduction_text
      text = %q(
        <p>
            This comparison benchmark is an alternative to the more commonly used
            per pupil energy comparison
            benchmark. <%= CAVEAT_TEXT[:es_per_pupil_v_per_floor_area] %>
        </p>
      )
      ERB.new(text).result(binding)
    end
  end
  #=======================================================================================
  class BenchmarkContentChangeInEnergyUseSinceJoined < BenchmarkContentBase
    include BenchmarkingNoTextMixin

    private def introduction_text
      text = %q(
        <p>
          This benchmark compares the change in annual energy use since the school
          joined Energy Sparks.
        </p>
      )
      ERB.new(text).result(binding)
    end
    protected def chart_interpretation_text
      text = %q(
        <p>
          Not all schools will be representated in this data, as we need 1 year&apos;s
          worth of data before the school joined Energy Sparks and at least 1 year
          after to do the comparison.
        </p>
      )
      ERB.new(text).result(binding)
    end

    def content(school_ids: nil, filter: nil, user_type: nil)
      content1 = super(school_ids: school_ids, filter: filter)
      content2 = full_energy_change_breakdown(school_ids: school_ids, filter: filter)
      content1 + content2
    end

    private
    
    def full_energy_change_breakdown(school_ids:, filter:)
      content_manager = Benchmarking::BenchmarkContentManager.new(@asof_date)
      db = @benchmark_manager.benchmark_database
      content_manager.content(db, :change_in_energy_use_since_joined_energy_sparks_full_data, filter: filter)
    end
  end
  #=======================================================================================
  class BenchmarkContentChangeInEnergyUseSinceJoinedFullData < BenchmarkContentBase
    include BenchmarkingNoTextMixin

    private def introduction_text
      text = %q(
        <p>
          This table provides a more detailed breakdown of the data provided in the chart
          and table above.
        </p>
      )
      ERB.new(text).result(binding)
    end
  end
  #=======================================================================================
  # this benachmark generates 2 charts and 1 table
  class BenchmarkContentChangeInCO2SinceLastYear < BenchmarkContentBase
    include BenchmarkingNoTextMixin

    private def introduction_text
      text = %q(
        <p>
          This benchmark compares the change in annual CO2 emissions between the last two years.
          All CO2 is expressed in kg (kilograms).
        </p>
      )
      ERB.new(text).result(binding)
    end

    def content(school_ids: nil, filter: nil, user_type: nil)
      content1 = super(school_ids: school_ids, filter: filter)
      content2 = full_co2_breakdown(school_ids: school_ids, filter: filter)
      content1 + content2
    end

    private
    
    def full_co2_breakdown(school_ids:, filter:)
      content_manager = Benchmarking::BenchmarkContentManager.new(@asof_date)
      db = @benchmark_manager.benchmark_database
      content_manager.content(db, :change_in_co2_emissions_since_last_year_full_table, filter: filter)
    end
  end
  #=======================================================================================
  class BenchmarkContentChangeInCO2SinceLastYearFullData  < BenchmarkContentBase
    include BenchmarkingNoTextMixin

    private def introduction_text
      %q(
        <p>
          This chart provides a breakdown of the change in CO2 emissions
          between electricity, gas and solar PV, and allows you to see which
          has increased and decreased.
        </p>
        <p>
          Generally an increase in solar PV production between last year and the year
          before, would lead to a reduction in CO2 emissions in the chart below,
          as the more electricity is produced by a school&apos;s solar PV panels
          the less CO2 a school emits overall.
        </p>
      )
    end

    protected def table_introduction_text
      %q( 
        <p>
          The solar PV CO2 columns in the table below are emissions the school saves from consuming
          electricity produced by its solar panels, and the benefit to the national grid from exporting
          surplus electricity. It&apos;s negative because it reduces the school&apos;s overall carbon emissions.
          The solar CO2 is calculated as the output of the panels times the carbon intensity of the
          national grid at the time of the output (half hour periods). So for example a reduction
          in CO2 offset by the school&apos;s panels from one year to the next doesn&apos;t necessarily
          imply a loss of performance of the panels but potentially a decarbonisation of the grid.
          As the grid decarbonises solar PV will gradually have a lower impact on reducing a
          school&apos;s carbon emissions, but conversely the school&apos;s carbon emissions
          from grid consumption will be lower.
        </p>
      )
    end
  end
  #=======================================================================================
  class BenchmarkOptimumStartAnalysis  < BenchmarkContentBase
    include BenchmarkingNoTextMixin

    private def introduction_text
      %q(
        <p>
          This experimental analysis attempts to help determine whether
          a school&apos;s optimum start control is working by looking at
          the times the boiler has started over the last year.
        </p>
      )
    end

    protected def table_introduction_text
      %q( 
        <p>
          The &apos;standard deviation&apos; column shows over how many hours
          the starting time has varied over the last year. If this is more than
          an hour or so, it might indicate the optimum start control is working,
          or it could be that someone has made lots of adjustments to the boiler
          start time during the year.
        </p>
        <p>
          The &apos;Regression model optimum start R2&apos; indicates how well
          correlated with outside temperature the start time of the boiler was.
          The closer to 1.0, the more correlated it was and therefore the
          more likely the optimum start control is working well.
        </p>
      )
    end

    protected def caveat_text
      %q(
        <p>
          However, these calculations are experimental and might not provide
          good indicators of how well the optimum start is working for all schools.
          Drilling down to look at the data for an individual school should provide
          a better indication.
        <p>
      )
    end
  end
  #=======================================================================================  
  class BenchmarkContentElectricityMeterConsolidation < BenchmarkContentBase
    include BenchmarkingNoTextMixin
    private def introduction_text
      %q(
        <p>
          Electricity meters can have quite high standing charges, between &pound;500
          and &pound;5,000 per year. If a school has several electricity meters
          it might be worth consolidating them i.e. getting your local electricity
          network provider or energy company to reduce the number of meters in a
          school to reduce annual standing order costs, this consolidation
          often costs about &pound;1,000.
        </p>
        <p>
          You need to consider how far apart the meters are, if for example they
          are in the same room or cupboard the change could cost you very little.
          The choice can also be determined by whether you have storage heaters,
          historically it would have been cheaper to have them on a separate meter,
          but with the advent of smart and advanced meters 10 years ago this is
          less necessary as your energy supplier can read you meters half hourly
          and can charge the appropriate lower cost for your overnight usage.
        </p>
        <p>
          This is a simple low cost change a school can make, the chart and table below
          attempt to estimate the potential saving based on some indicative standing charges
          for your area; you will need to look at your bills to get a more accurate
          estimate.
        </p>
      )
    end

    def table_introduction_text
      %q(
        <p>
          Opportunities to save money through consolidation will only
          exist if a school has multiple electricity meters.
        </p>
      )
    end
  end
  #=======================================================================================  
  class BenchmarkContentGasMeterConsolidation < BenchmarkContentBase
    include BenchmarkingNoTextMixin
    private def introduction_text
      %q(
        <p>
          Gas meters can have quite high standing charges, between &pound;500
          and &pound;5,000 per year. If a school has a number of gas meters
          it might be worth consolidating them i.e. getting your local gas
          network provider or energy company to reduce the number of meters in a
          school to reduce annual standing order costs, this consolidation
          often costs about &pound;1,000 but can provide guaranteed annual savings.
        </p>
      )
    end

    def table_introduction_text
      %q(
        <p>
          Opportunities to save money through consolidation will only
          exist if a school has multiple gas meters.
        </p>
      )
    end
  end
  #=======================================================================================  
  class BenchmarkContentDifferentialTariffOpportunity < BenchmarkContentBase
    include BenchmarkingNoTextMixin
    private def introduction_text
      %q(
        <p>
          Electricity is generally charged at a flat rate, for example 15p/kWh
          whatever the time of day. Your energy company&apos;s costs however
          vary significantly depending on supply and demand at different times
          of day, from perhaps 4p/kWh overnight to 25p/kWh at peak times.
          Electricity companies generally offer differential tariff&apos;s
          (economy 7) which have lower overnight costs (typically 15p/kWh) and
          slightly higher daytime costs (16p/kWh) to users who have high overnight
          consumption to share the benefit of cheaper overnight wholesale costs.
        </p>
        <p>
          Typically, this should benefit schools with storage heaters, however
          many schools with storage heaters are on a single flat tariff and fail
          to gain from lower overnight prices.
        </p>
        <p>
          The chart and table below estimate the potential benefit of switching
          to or from a differential tariff.
        </p>
      )
    end
  end
  #=======================================================================================  
  class BenchmarkContentChangeInElectricityConsumptionSinceLastSchoolWeek < BenchmarkContentBase
    include BenchmarkingNoTextMixin
    private def introduction_text
      text = %q(
        <p>
          This comparison simply shows the change in electricity consumption since the
          last school week. You should expect a slight but not significant
          increase in electricity consumption going into the winter with
          increased lighting usage and a subsequent reduction in the spring.
        </p>
        <%= CAVEAT_TEXT[:comparison_with_previous_period_infinite] %>
      )
      ERB.new(text).result(binding)
    end
  end
  #=======================================================================================  
  class BenchmarkContentChangeInElectricityBetweenLast2Holidays < BenchmarkContentBase
    include BenchmarkingNoTextMixin
    private def introduction_text
      text = %q(
        <p>
          This comparison shows the change in consumption between the 2 most recent holidays.
        </p>
        <%= CAVEAT_TEXT[:comparison_with_previous_period_infinite] %>
      )
      ERB.new(text).result(binding)
    end
  end
  #=======================================================================================  
  class BenchmarkContentChangeInElectricityBetween2HolidaysYearApart < BenchmarkContentBase
    include BenchmarkingNoTextMixin
    private def introduction_text
      text = %q(
        <p>
          This comparison shows the change in consumption the most recent holiday, and
          the same holiday a year ago. Schools should be looking to reduce holiday usage
          by switching appliances off and generally reducing baseload. An increase
          from year to year suggests a school is not managing to reduce consumption,
          which would help mitigate some of the impacts of climate change.
        </p>
        <%= CAVEAT_TEXT[:comparison_with_previous_period_infinite] %>
      )
      ERB.new(text).result(binding)
    end
  end
  #=======================================================================================  
  class BenchmarkContentChangeInGasConsumptionSinceLastSchoolWeek < BenchmarkContentBase
    include BenchmarkingNoTextMixin
    private def introduction_text
      text = %q(
        <p>
          This comparison simply shows the change in gas consumption since the
          last school week. You might expect an
          increase in gas consumption going into the winter as it gets
          colder and a subsequent reduction in the spring.
        </p>
        <%= CAVEAT_TEXT[:comparison_with_previous_period_infinite] %>
      )
      ERB.new(text).result(binding)
    end
  end
  #=======================================================================================  
  class BenchmarkContentChangeInGasBetweenLast2Holidays < BenchmarkContentBase
    include BenchmarkingNoTextMixin
    private def introduction_text
      text = %q(
        <p>
          This comparison shows the change in consumption between the 2 most recent holidays.
          This can be affected by whether the heating was turned on one of the holidays,
          and not on the other.
          Generally, schools don&apos;t need heating during holidays, or at least not
          to heat the whole school if minimally occupied! Using an electric fan heater
          is always more cost effective for a few individuals in the school during holidays
          than heating the whole school.
        </p>
        <p>
          You can setup an Energy Sparks
          &apos;alert&apos; to send you an email or text message just before a holiday to remind you to
          turn heating or hot water off.
        </p>
        <%= CAVEAT_TEXT[:comparison_with_previous_period_infinite] %>
      )
      ERB.new(text).result(binding)
    end
  end
  #=======================================================================================  
  class BenchmarkContentChangeInGasBetween2HolidaysYearApart < BenchmarkContentBase
    include BenchmarkingNoTextMixin
    private def introduction_text
      text = %q(
        <p>
          This comparison shows the change in consumption the most recent holiday, and
          the same holiday a year ago. Schools should be looking to reduce holiday usage
          by switching heating and hot water off over holidays when it is often unnecessary.
          A significant  increase from year to year suggests a school is not managing to reduce consumption,
          which would help mitigate some of the impacts of climate change. You can setup an Energy Sparks &apos;alert&apos; to
          send you an email or text message just before a holiday to remind you to
          turn heating or hot water off.
        </p>
        <%= CAVEAT_TEXT[:comparison_with_previous_period_infinite] %>
      )
      ERB.new(text).result(binding)
    end
  end
end
