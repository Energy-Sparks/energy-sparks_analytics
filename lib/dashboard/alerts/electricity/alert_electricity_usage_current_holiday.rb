# only during holidays this alert send messages or for school comparison/benchmark
class AlertElectricityUsageDuringCurrentHoliday < AlertElectricityOnlyBase
  attr_reader :holiday_usage_to_date_kwh, :holiday_projected_usage_kwh
  attr_reader :holiday_usage_to_date_£,   :holiday_projected_usage_£
  attr_reader :holiday_usage_to_date_co2, :holiday_projected_usage_co2

  def initialize(school)
    super(school, :holiday_electricity_usage_to_date)
    @relevance = :never_relevant unless @school.holidays.holiday?(@today)
  end

  def self.template_variables
    specific = {'Electricity usage during current holiday' => TEMPLATE_VARIABLES}
    specific.merge(self.superclass.template_variables)
  end

  TEMPLATE_VARIABLES = {
    holiday_name: {
      description: 'Name of holiday',
      units:  String,
      benchmark_code: 'hnam',
    },
    holiday_usage_to_date_kwh: {
      description: 'Usage so far this holiday - kwh',
      units:  :kwh
    },
    holiday_projected_usage_kwh: {
      description: 'Projected usage for whole holiday - kwh',
      units:  :kwh
    },
    holiday_usage_to_date_£: {
      description: 'Usage so far this holiday - £',
      units:  :£,
      benchmark_code: '£sfr'
    },
    holiday_projected_usage_£: {
      description: 'Projected usage for whole holiday - £',
      units:  :£,
      benchmark_code: '£pro'
    },
    holiday_usage_to_date_co2: {
      description: 'Usage so far this holiday - co2',
      units:  :co2
    },
    holiday_projected_usage_co2: {
      description: 'Projected usage for whole holiday - co2',
      units:  :co2
    },
    summary: {
      description: 'Summary of holiday usage',
      units:  String
    },
  }

  def relevance
    @relevance
  end

  def enough_data
    holiday_period = @school.holidays.holiday(@today)
    if !holiday_period.nil? &&
       aggregate_meter.amr_data.start_date <= holiday_period.start_date &&
       aggregate_meter.amr_data.end_date   >= holiday_period.start_date
      :enough
    else
      :not_enough
    end
  end

  def time_of_year_relevance
    set_time_of_year_relevance(@relevance == :relevant ? 10.0 : 0.0)
  end

  protected def max_days_out_of_date_while_still_relevant
    14
  end

  def timescale
    I18n.t("#{i18n_prefix}.timescale")
  end

  private

  def calculate(asof_date)
    if @school.holidays.holiday?(asof_date)
      @relevance = :relevant

      @holiday_period     = @school.holidays.holiday(asof_date)
      holiday_date_range  = @holiday_period.start_date..@holiday_period.end_date

      usage_to_date  = calculate_usage_to_date(holiday_date_range)
      totals_to_date = totals(usage_to_date)
      workdays_days, weekend_days = holiday_weekday_workday_stats(holiday_date_range)
      projected_totals = calculate_projected_totals(usage_to_date, workdays_days, weekend_days)

      @holiday_usage_to_date_kwh   = totals_to_date[:kwh]
      @holiday_projected_usage_kwh = projected_totals[:kwh]

      @holiday_usage_to_date_£   = totals_to_date[:£]
      @holiday_projected_usage_£ = projected_totals[:£]

      @holiday_usage_to_date_co2   = totals_to_date[:co2]
      @holiday_projected_usage_co2 = projected_totals[:co2]

      @rating = 0.0
    else
      @relevance = :never_relevant
      @holiday_name = 'Not a holiday'

      @holiday_usage_to_date_£   = 0.0
      @holiday_projected_usage_£ = 0.0

      @rating = 10.0
    end

    @term = :shortterm
  end
  alias_method :analyse_private, :calculate

  def calculate_usage_to_date(holiday_date_range)
    amr = aggregate_meter.amr_data
    start_date = [holiday_date_range.first, amr.start_date].max
    end_date   = [holiday_date_range.last,  amr.end_date, @today].min

    lamda = -> (date, data_type) { amr.one_day_kwh(date, data_type) }
    classifier = -> (date) { day_type(date) }

    %i[kwh £ co2].map do |data_type|
      [
        data_type,
        @school.holidays.calculate_statistics(start_date, end_date, lamda, classifier: classifier, args: data_type, statistics: %i[total average count])
      ]
    end.to_h
  end

  def holiday_name
    @holiday_period.title
  end

  def totals(usage_to_date)
    usage_to_date.transform_values{ |v| v.values.map { |vv| vv[:total] }.compact.sum }
  end

  def day_type(date)
    date.saturday? || date.sunday? ? :weekend : :workday
  end

  def holiday_weekday_workday_stats(holiday_date_range)
    weekend_days  = holiday_date_range.count { |d| weekend?(d) }
    workdays_days = holiday_date_range.last -  holiday_date_range.first + 1 - weekend_days
    [workdays_days, weekend_days]
  end

  def calculate_projected_totals(usage_to_date, workdays_days, weekend_days)
    usage_to_date.transform_values do |v|
      # at start of holiday may only have sample weekend or weekday,
      # so use backup type if missing sample i.e. workday if no weekend day sample etc.
      workdays_days * (v.dig(:workday, :average) || v.dig(:weekend, :average)) +
      weekend_days  * (v.dig(:weekend, :average) || v.dig(:workday, :average))
    end
  end

  def summary
    if @today < @holiday_period.end_date
      I18n.t("#{i18n_prefix}.holiday_cost_to_date",
        holiday_name: holiday_name,
        date: I18n.l(@asof_date, format: '%A %e %b %Y'),
        cost_to_date: FormatEnergyUnit.format(:£, @holiday_usage_to_date_£) ) +
      I18n.t("#{i18n_prefix}.holiday_predicted_cost",
        predicted_cost: FormatEnergyUnit.format(:£, @holiday_projected_usage_£))
    else
      I18n.t("#{i18n_prefix}.holiday_cost_to_date",
        holiday_name: holiday_name,
        date: I18n.l(@asof_date, format: '%A %e %b %Y'),
        usage_to_date: FormatEnergyUnit.format(:£, @holiday_usage_to_date_£) )
    end
  end
end
