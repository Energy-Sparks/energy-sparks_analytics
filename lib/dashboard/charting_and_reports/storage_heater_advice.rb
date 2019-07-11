require 'erb'

# extension of DashboardEnergyAdvice for heating regression model fitting
# NB clean HTML from https://word2cleanhtml.com/cleanit
class DashboardEnergyAdvice

  def self.storage_heater_advice_factory(chart_type, school, chart_definition, chart_data, chart_symbol)
    case chart_type
    when :storage_heater_group_by_week
      StorageHeaterGroupByWeekAdvice.new(school, chart_definition, chart_data, chart_symbol)
    when :storage_heater_group_by_week_long_term
      StorageHeaterWeeklyLongTermAdvice.new(school, chart_definition, chart_data, chart_symbol)
    when :storage_heater_by_day_of_week
      StorageHeaterDayOfWeekAdvice.new(school, chart_definition, chart_data, chart_symbol)
    when :storage_heater_intraday_current_year
      StorageHeaterHeatingIntradayAdvice.new(school, chart_definition, chart_data, chart_symbol)
    when :storage_heater_intraday_current_year_kw
      StorageHeaterHeatingIntradayKWAdvice.new(school, chart_definition, chart_data, chart_symbol)
    when :intraday_line_school_last7days_storage_heaters
      StorageHeaterLast7DaysIntraday.new(school, chart_definition, chart_data, chart_symbol)
    when :storage_heater_thermostatic
      StorageHeaterThermostaticAdvice.new(school, chart_definition, chart_data, chart_symbol)
    when :heating_on_off_by_week_storage_heater
      StorageHeaterModelFittingSplittingHeatingAndNonHeating.new(school, chart_definition, chart_data, chart_symbol)
    else
      nil
    end
  end

  class StorageHeaterAdviceBase < GasWeeklyAdvice
    protected def annual_usage(day_type_type = 'Weekend', units = :kwh)
      data = ScalarkWhCO2CostValues.new(@school)
      usage_kwh = data.day_type_breakdown({year: 0}, :storage_heaters, units, units)[day_type_type]
      usage_kwh
    end
  end

  class StorageHeaterGroupByWeekAdvice < StorageHeaterAdviceBase
    def generate_advice
      header_template = %{
        <%= @body_start %>
          <p>
            Your school has storage heaters. They work differently from other forms of
            heating in that they consume electricity overnight, store the energy, and
            then release the stored heat to classrooms during the day. In contrast most
            gas heating systems consume gas to produce heat immediately, so only
            consume energy during the school day.
          </p>
          <p>
            Most storage heaters work by storing the heat in 'bricks' which are
            contained within the storage heater radiators. These radiators are
            generally quite large as they need to contain enough bricks to provide heat
            to a classroom for a whole day.
          </p>
          <p>
            Storage heaters can be very inefficient as they don't know how cold it is
            likely to be during the following day, and therefore how much heat to
            download and store from the electricity grid overnight. They therefore try
            to store as much heat as possible whether the following day is likely to be
            hot or cold.
          </p>
          <p>
            Storage heaters try to save money by making use of cheaper overnight
            electricity (economy 7, differential tariff) which costs about 7p/kWh
            compared with 12p/kWh for daytime electricity. Overnight electricity is
            cheaper to produce because there is less demand.
          </p>
          <p>
            Further information on (domestic) storage heaters can be found by
            <a
              href="https://www.cse.org.uk/advice/advice-and-support/night-storage-heaters"
              target="_blank"
            >clicking here</a>
            .
          </p>
          <p>
            The chart below shows your storage heater electricity consumption broken
            down on a weekly basis across the last year
          </p>
        <%= @body_end %>
      }.gsub(/^  /, '')
  
      @header_advice = generate_html(header_template, binding)
  
      footer_template = %{
        <%= @body_start %>
          <p>
            Generally, consumption should peak in the winter when it is coldest and the
            school requires most heat. The second axis, 'Degree Day' line on the chart
            above is an indication of how cold it was, so the higher the line the
            colder the outside temperature.
          </p>
          <p>
            <strong>Question</strong>
            : Does your school consume more electricity for storage heating in the
            winter than the summer? How well does the electricity consumption (bar
            chart) follow the 'Degree Day' line? (If control of the storage heaters is
            good it should follow quite well)
          </p>
          <blockquote class="bg-gray primary">
            <p>
              <strong>Question</strong>
              : The chart also highlights usage at weekends and holidays. Did your school
              leave the storage heaters on over the holidays? Sometimes it might be
              necessary to leave them on to avoid frost damage to cold water pipework,
              but many classrooms have no cold water, so storage heaters can be turned
              off over holidays, and where they do have cold water pipework, the heaters
              can be turned down to their minimum settings. If they have been left on
              over holidays - could your school set a policy to turn them off (e.g. set
              an entry in the school diary for the end of each term for the caretaker to
              go around and switch off, or turn down the storage heaters)?
            </p>
          </blockquote>

          <p>
            <strong>Answer</strong>
            <%= annual_usage('Holiday', :kwh) %> or <%= annual_usage('Holiday', :£) %> per year
             if you turn your storage heaters off during holidays.
            and 
            <%= annual_usage('Weekend', :kwh) %> or <%= annual_usage('Weekend', :£) %> per year
            at weekends (term time)
          </p>
        <%= @body_end %>
      }.gsub(/^  /, '')
  
      @footer_advice = generate_html(footer_template, binding)
    end
  end

  class StorageHeaterWeeklyLongTermAdvice < StorageHeaterAdviceBase
    def generate_advice
      header_template = %{
        <%= @body_start %>
          <p>
            The following chart provides the same information as the chart above but
            over a longer period:
          </p>
        <%= @body_end %>
      }.gsub(/^  /, '')
  
      @header_advice = generate_html(header_template, binding)
  
      footer_template = %{
        <%= @body_start %>
          <p>
            <strong>Question</strong>
            : Can you see any difference from year to year in the chart above?
          </p>
        <%= @body_end %>
      }.gsub(/^  /, '')
  
      @footer_advice = generate_html(footer_template, binding)
    end
  end

  class StorageHeaterDayOfWeekAdvice < StorageHeaterAdviceBase
    def generate_advice
      header_template = %{
        <%= @body_start %>
          <p>
            This chart shows the breakdown of the consumption of electricity by storage
            heaters by day of the week:
          </p>
        <%= @body_end %>
      }.gsub(/^  /, '')

      @header_advice = generate_html(header_template, binding)

      footer_template = %{
        <%= @body_start %>
          <p>
            <strong>Question</strong>
            : Are there any differences between the days of the week - if so can you
            explain them?
          </p>
          <p>
            <strong>Question</strong>
            : At many schools the storage heaters are left on at weekends because the
            timer doesn't understand days of the week (24 hour timer)? Are storage
            heaters left on at your school during the weekend? Installing a '7-day'
            timer which might cost the school &#163;300 could save your school
            <%= annual_usage %> or <%= annual_usage('Weekend', :£) %> per year. Contact Energy Sparks
            <a href="mailto:hello@energysparks.uk?subject=Help with changing storage heater timers&">hello@energysparks.uk</a>
            for advice on changing timers if you
            need help?
          </p>
        <%= @body_end %>
      }.gsub(/^  /, '')
      @footer_advice = generate_html(footer_template, binding)
    end 
  end

  class StorageHeaterHeatingIntradayAdvice < StorageHeaterAdviceBase
    def generate_advice
      header_template = %{
        <%= @body_start %>
          <p>
            The chart below shows the average storage heater electricity consumption for the
            last year broken down by time of day:
          </p>
        <%= @body_end %>
      }.gsub(/^  /, '')
  
      @header_advice = generate_html(header_template, binding)
  
      footer_template = %{
        <%= @body_start %>
          <p>
            Storage heaters typically start consuming electricity at midnight or soon
            after, until about 06:30am, this energy is stored within the storage heater
            while electricity is cheap and then released later during the school day.
            Generally, consumption drops gradually in this early morning period because
            the 'bricks' within the storage heater get hotter and the rate at which it
            is possible to charge the bricks slows down.
          </p>
        <%= @body_end %>
      }.gsub(/^  /, '')
  
      @footer_advice = generate_html(footer_template, binding)
    end
  end

  class StorageHeaterHeatingIntradayKWAdvice < StorageHeaterAdviceBase
    def generate_advice
      header_template = %{
        <%= @body_start %>
          <p>
            This is a chart of the average power consumption of your storage heaters,
            and is provided as additional information:
          </p>
        <%= @body_end %>
      }.gsub(/^  /, '')
  
      @header_advice = generate_html(header_template, binding)
  
      footer_template = %{
        <%= @body_start %>
        <%= @body_end %>
      }.gsub(/^  /, '')
  
      @footer_advice = generate_html(footer_template, binding)
    end
  end

  class StorageHeaterLast7DaysIntraday < StorageHeaterAdviceBase
    def generate_advice
      header_template = %{
        <%= @body_start %>
          <p>
            This chart is only useful during the winter when the storage heaters are
            turned on, and displays the storage heater electricity consumption for the
            last 7 days:
          </p>
        <%= @body_end %>
      }.gsub(/^  /, '')
  
      @header_advice = generate_html(header_template, binding)
  
      footer_template = %{
        <%= @body_start %>
          <p>
            Its useful to understand whether the storage heaters are working the same
            on every weekday. You can click on the legend below the chart to add or
            remove days.
          </p>
        <%= @body_end %>
      }.gsub(/^  /, '')
  
      @footer_advice = generate_html(footer_template, binding)
    end
  end

  class StorageHeaterThermostaticAdvice < HeatingAnalysisBase
    def initialize(school, chart_definition, chart_data, chart_symbol, meter_type = :storage_heater_meter)
      super(school, chart_definition, chart_data, chart_symbol, meter_type)
    end

    def generate_advice
      header_template = %{
        <%= @body_start %>
          <p>
            Thermostatic control is a way of assessing how well heating systems react
            to changes in outside temperature. Good thermostatic control is indicated
            by a linear relationship between the daily electricity consumption and how
            cold it is outside. So, on a day which is twice as cold you might expect
            twice the electricity consumption. Heating systems with good thermostatic
            control are generally those whose thermostats control the output of
            radiators well. Unfortunately, for storage heaters this is difficult
            because they consume the electricity overnight with no reference to the
            subsequent heating demand during the day.
          </p>
          <p>
            This chart plots the outside temperature (x axis) versus the storage heater
            electricity consumption for all the days of the last year when the storage
            heaters were turned on.
          </p>
        <%= @body_end %>
      }.gsub(/^  /, '')

      @header_advice = generate_html(header_template, binding)

      footer_template = %{
        <%= @body_start %>
          <p>
            The key measure on the chart above is the R<sup>2</sup> value (see trend
            line legend which indicates a value of <%= r2.round(2) %> ), which
            indicates how close on average the electricity consumption points are to
            the trendline. The higher the value, the better, a value of 1.0 is perfect
            and a value of 0.0 very poor. Generally, for storage heaters a value above
            0.5 would be described as 'good'. If the value is significantly less ,then
            it might be useful to look at the settings and positioning of the
            thermostats which control each radiator. Improving thermostatic control
            will save costs and mean classroom temperatures are more consistent and
            comfortable, rather than being too hot or cold at different times of the
            year.
          </p>
        <%= @body_end %>
      }.gsub(/^  /, '')
  
      @footer_advice = generate_html(footer_template, binding)
    end
  end

  class StorageHeaterModelFittingSplittingHeatingAndNonHeating < HeatingAnalysisBase
    def initialize(school, chart_definition, chart_data, chart_symbol, meter_type = :storage_heater_meter)
      super(school, chart_definition, chart_data, chart_symbol, meter_type)
    end

    def generate_advice
      header_template = %{
        <%= @body_start %>
          <p>
            The chart below indicates how many weeks of the year the storage heaters
            have been left on:
          </p>
        <%= @body_end %>
      }.gsub(/^  /, '')
  
      @header_advice = generate_html(header_template, binding)
  
      footer_template = %{
        <%= @body_start %>
          <p>
            This is an indication of the 'heating season', i.e. the period in the
            Autumn when heating is turned on, until the period in Spring when it is
            turned off again for the summer when heating is not needed. Most schools
            turn the heating on after the Autumn half term holiday in November, and off
            after Easter in April, or perhaps a little later if its an early Easter
            holiday.
          </p>
          <p>
            On average, schools have their heating on for <%= average_school_heating_days %> days per year.
            Your school had its heating on for <%= heating_days %> days
            which is <%= heating_days_adjective %>. To improve this, you
            could shorten your heating season and ensure heating is not left on during
            weekends and holidays. The easiest way to reduce your heating season is to
            setup an alert in Energy Sparks which will email you and indicate when to
            turn the heating on and off depending on the upcoming weather forecast for
            the week. Please contact us if you would like help setting up the alert
            (
              <a href="mailto:hello@energysparks.uk?subject=Help with setting up alerts for my school storage heaters&">hello@energysparks.uk</a>
            )
          </p>
          <p>
            <strong>Question</strong>
            : How well did your school manage the turning on and off of your storage
            heaters over last year? Was the heating season too long, were the heaters
            turned off during holidays?
          </p>
        <%= @body_end %>
      }.gsub(/^  /, '')
  
      @footer_advice = generate_html(footer_template, binding)
    end

    private def heating_days
      @days_heating ||= heating_model.number_of_heating_school_days
    end

    private def heating_days_adjective
      AnalyseHeatingAndHotWater::HeatingModel.school_heating_day_adjective(heating_days)
    end

    def average_school_heating_days
      AnalyseHeatingAndHotWater::HeatingModel.average_school_heating_days
    end
  end
end
