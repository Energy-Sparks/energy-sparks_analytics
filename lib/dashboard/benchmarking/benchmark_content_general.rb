require_relative './benchmark_no_text_mixin.rb'
module Benchmarking
  class BenchmarkContentElectricityPerPupil < BenchmarkContentBase
    private def introduction_text
      %q(
        <p>
          This benchmark compares the electricity consumed per pupil each year,
          expressed in pounds.
        </p>
        <p>
          A realistic target for the primary school to use less than
          &pound;20 per pupil per year, for middle schools &pound;30
          and for secondaries &pound;40. 
        </p>
      )
    end
  end

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

