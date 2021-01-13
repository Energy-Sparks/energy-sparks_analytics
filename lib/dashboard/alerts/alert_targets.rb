class AlertTargetBase < AlertAnalysisBase
  attr_reader :this_year_£, :last_year_£, :year_change_£, :relevance
  attr_reader :percent_change_£, :summary

  def initialize(school, type = :electricitylongtermtrend)
    super(school, type)
    @target_school = TargetSchool.new(school, :day)
    @relevance = aggregate_target_meter.nil? ? :never_relevant : :relevant
  end

  def enough_data
    days_amr_data_with_asof_date(@asof_date) > 365 ? :enough : :not_enough
  end

  def timescale
    'at least 1 year'
  end

  def self.long_term_variables(fuel_type)
    {
      this_year_£: {
        description: "This years #{fuel_type} consumption £",
        units:  :£
      },
      last_year_£: {
        description: "Last years #{fuel_type} consumption £",
        units:  :£
      },
      year_change_£: {
        description: "Change between this year\'s and last year\'s #{fuel_type} consumption £",
        units:  :£
      },
      percent_change_£: {
        description: "Change between this year\'s and last year\'s #{fuel_type} consumption %",
        units:  :relative_percent
      },
      summary: {
        description: 'Change in £spend, relative to previous year',
        units: String
      },

      tracking_start_date: {
        description: 'Start of a academic year date for tracking',
        units:  :date
      },
      tracking_end_date: {
        description: 'End of a academic year date for tracking',
        units:  :date
      },
      previous_year_start_date: {
        description: 'Start of previous academic year date for tracking',
        units:  :date
      },
      previous_year_end_date: {
        description: 'End of previous academic year date for tracking',
        units:  :date
      },
      previous_year_kwh: {
        description: 'Previous year (annual) kwh',
        units:  :kwh
      },
      previous_year_co2: {
        description: 'Previous year (annual) co2 in kg',
        units:  :co2
      },
      previous_year_£: {
        description: 'Previous year (annual) £cost',
        units:  :£
      },
      current_year_kwh: {
        description: 'Current year year to date kwh',
        units:  :kwh
      },
      current_year_co2: {
        description: 'Current year year to date co2 in kg',
        units:  :co2
      },
      current_year_£: {
        description: 'Current year year to date £cost',
        units:  :£
      },
    }
  end

  def tracking_start_date
    @tracking_start_date ||= Date.new(academic_year.start_date.year, academic_year.start_date.month, 1)
  end

  def tracking_end_date
    Date.new(tracking_start_date.year + 1, tracking_start_date.month, 1)
  end

  def previous_year_start_date; previous_year_end_date - 363 end
  def previous_year_end_date;   tracking_start_date - 1 end

  def previous_year_kwh;        @previous_year_kwh ||= previous_year_total(:kwh) end
  def previous_year_co2;        @previous_year_co2 ||= previous_year_total(:co2) end
  def previous_year_£;          @previous_year_£   ||= previous_year_total(:£) end

  def current_year_kwh;         @current_year_kwh ||= current_year_total(:kwh) end
  def current_year_co2;         @current_year_co2 ||= current_year_total(:co2) end
  def current_year_£;           @current_year_£   ||= current_year_total(:£) end

  def current_year_target_kwh; @current_year_target_kwh ||= current_year_target_total(:kwh) end
  def current_year_target_co2; @current_year_target_co2 ||= current_year_target_total(:co2) end
  def current_year_target_£;   @current_year_target_£   ||= current_year_target_total(:£) end

  def aggregate_meter_end_date
    @school.aggregate_meter(fuel_type).amr_data.end_date
  end

  def maximum_alert_date
    aggregate_meter.amr_data.end_date
  end

  private def calculate(asof_date)
    puts "Got here #{previous_year_kwh}"
    raise EnergySparksNotEnoughDataException, "Not enough data: 2 years of data required, got #{days_amr_data} days" if enough_data == :not_enough
    scalar = ScalarkWhCO2CostValues.new(@school)
    @this_year_£        = scalar.aggregate_value({ year:  0 }, fuel_type, :£, { asof_date: asof_date})
    @last_year_£        = scalar.aggregate_value({ year: -1 }, fuel_type, :£, { asof_date: asof_date})
    @year_change_£      = @this_year_£ - @last_year_£
    @percent_change_£   = @year_change_£ / @last_year_£
    @summary            = summary_text
    puts "Got here hhhhh"

    @rating = calculate_rating_from_range(-0.1, 0.15, percent_change_£)

    set_savings_capital_costs_payback(Range.new(year_change_£, year_change_£), nil)
  end
  alias_method :analyse_private, :calculate

  def summary_text
    "Hello world"
  end

  def academic_year
    @academic_year ||= calculate_academic_year
  end

  def calculate_academic_year
    year = @school.holidays.academic_year(Date.today)
    if year.nil?
      # data commonly not being set for next summer holiday, so make a guess!!!!!!!!!!!
      previous_academic_year = @school.holidays.academic_year(Date.today - 364)
      year = SchoolDatePeriod.new(:academic_year, 'Synthetic approx current academic year', previous_academic_year.end_date + 1, previous_academic_year.end_date + 365)
    end
    year
  end

  def previous_year_total(datatype)
    total(false, previous_year_start_date, previous_year_end_date, datatype)
  end

  def current_year_total(datatype)
    total(false, tracking_start_date, tracking_end_date, datatype)
  end

  def current_year_target_total(datatype)
    total(true, tracking_start_date, tracking_end_date, datatype)
  end

  def total(use_target, start_date, end_date, datatype)
    begin
      chosen_school = use_target ? @target_school : @school
      end_date = [end_date, aggregate_meter_end_date].min
      chosen_school.aggregate_meter(fuel_type).amr_data.kwh_date_range(start_date, end_date, datatype)
    rescue EnergySparksNotEnoughDataException => _e
      nil
    end
  end
end

class AlertElectricityTarget < AlertTargetBase
  def self.template_variables
    specific = { 'Electricity targetting and tracking' => long_term_variables('electricity')}
    specific.merge(self.superclass.template_variables)
  end

  def fuel_type
    :electricity
  end

  def aggregate_meter
    @school.aggregated_electricity_meters
  end

  def aggregate_target_meter
    @target_school.aggregated_electricity_meters
  end
end

class AlertGasTarget < AlertTargetBase
  def self.template_variables
    specific = { 'Gas targetting and tracking' => long_term_variables('gas')}
    specific.merge(self.superclass.template_variables)
  end

  def fuel_type
    :gas
  end

  def aggregate_meter
    @school.aggregated_heat_meters
  end

  def aggregate_target_meter
    @target_school.aggregated_heat_meters
  end
end
