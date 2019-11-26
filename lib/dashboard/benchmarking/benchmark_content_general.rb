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
        at energy consumption.
      </p>
    ),
    es_data_not_in_sync: %q(
      <p>
        The gas, electricity and storage heater costs are all using the latest
        data. The total might not be the sum of these 3 in the circumstance
        where one of the meter's data is out of date, and the total covers the
        most recent year where data is available to us on all the underlying
        meters.
      </p>
    ),
    es_per_pupil_v_per_floor_area: %q(
      <p>
          Generally per pupil benchmarks are appropriate for electricity
          (should be proportional to the appliances e.g. ICT in use),
          but per floor area benchmarks are more appropriate for gas (size of
          building which needs heating). FOr overall energy use comparison
          on a per pupil basis is probably more appropriate than on a per
          floor area basis.
      </p>
    ),
    es_exclude_storage_heaters_and_solar_pv: %q(
      <p>
        This breakdown excludes electricity consumed by storage heaters and
        solar PV.
      </p>
    )
  }
  #=======================================================================================
  class BenchmarkContentEnergyPerPupil < BenchmarkContentBase
    include BenchmarkingNoTextMixin
    private def introduction_text
      text = %q(
        <p>
          This benchmark compares the energy consumed per pupil each year,
          expressed in pounds.
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
          expressed in pounds.
        </p>
        <p>
          A realistic target for the primary school to use less than
          &pound;20 per pupil per year, for middle schools &pound;30
          and for secondaries &pound;40. There really shouln't be a
          signifcant difference between schools as all schools
          need to use roughly the same amount of ICT equipment,
          lighting and refridgeration per pupil. The biggest reductions
          can often be acheived by focussing on &apos;baseload&apos;
          ensuring equipment is turned off out of hours, and that the
          equipment which is left on is as efficient as possible.
        </p>
        <p>
          The data excludes storage heaters which are reported elsewhere
          under the &apos;sheating&apos;s benchmarks.
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
          this year and last year, excluding solar PV and storahe heaters.
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
          To make a signifcant contribution ot mitigating climate
          change schools should really be aiming to reduce their electricity
          consumption by 10% year on year - something which is easily achievable
          through a mixture of behavioural change and tactical investment in
          more efficient equipment.
        </p>
        <p>
          An increase in electricuity consumption, unless there has been a signficant
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
          Most schools are unoccupied for about 85% of the year;
          between 5:00pm and 7:30am on school days, at weekends
          and during holidays. Focussing on reducing out of hours
          usage; turning appliances off, installing efficient
          appliances often provides schools with a cost efficient
          way of reducing their overall consumption.
        </p>
        <p>
          Schools should aim to reduce their out of hours usage
          below 25% of annual consumption. In comparing schools
          it might be helpful for you to look at the 2 additional
          benchmarks on baseload (out of hours power consumption)
          that we provide as it might elicit more information
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
            of last year. Schools should be aiming to reduce baseload over time
            and not increase it as equipment and lighting has become significantly
            more efficient over the last few years. Any increase should be tracked
            down as soon as it is discovered. Energy Sparks can be configured
            to send you an alert via an email or a text message if it detects
            this has happened.
          </p>
          <p>
            A 1 kW increase in baseload is equivalent to an annual increase in
            electricity costs of £1,100.
          </p>
          <%= CAVEAT_TEXT[:es_exclude_storage_heaters_and_solar_pv] %>
        )
        ERB.new(text).result(binding)
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
          Generally if the weather last week was mild then your might
          expect the heating to be coming on at about 6:30am. In colder
          weather depending on the fabric (insulation, thermal mass) of
          the school you might expect the heating to start earlier at
          perhaps 3:00am. If its coming on earlier the school&apos;s boiler
          control probably warrants further investigation.
        </p>
        <p>
          If the boiler is coming on too early remedies include:
          <ul>
            <li>
              Monitoring temperature in the school in the early morning - typically
              available via the school&apos;s BMS or boiler controller, or via temperature
              logger (typically &pound;20)
            </li>
            <li>
              Has the school&apos;s thermostat been correctly located, if in a hall then
              classrooms might be up to temperature many hours before the hall, so perhaps
              the thermostat could be relocated or the hall&apos;s thermostat&apos;s settings
              could be lowered (16C or less)?
            </li>
            <li>
              Otherwise consider whether the radiator output is high enough to get the
              school up to temperature quickly? Fan convector radiators should take less
              than an hour to get a room up to temperature even in cold weather. Is the flow
              temperature high enough, does the pipework allow adequate distribution of heat,
              do the radiators have adequate output, have their TRVs been set too low for
              the main boiler thermostat?
            </li>
            <li>
                If the boiler&apos;s starting time has been set because school users have
                complained its too cold in the morning, consider experimenting
                with the start time. We generally recommened starting the boiler
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

    def content(school_ids: nil, filter: nil)
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
  class BenchmarkContentEnergyPerPupil < BenchmarkContentBase
    include BenchmarkingNoTextMixin

    private def introduction_text
      text = %q(
        <p>
            This comparison benchmark is an alternative to a per pupil energy
            benchmark. <%= CAVEAT_TEXT[:es_per_pupil_v_per_floor_area] %>
        </p>
      )
      ERB.new(text).result(binding)
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
          the starting time has varaied over the last year. If this is more than
          an hour or os, it might indicate the optimum start control is working,
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
          However these calculations are experimental and might not provide
          good indicators of how well the optimum start is working for all schools.
          Drilling down to look at the data for an individual school should provide
          a better indication.
        <p>
      )
    end
  end
end

