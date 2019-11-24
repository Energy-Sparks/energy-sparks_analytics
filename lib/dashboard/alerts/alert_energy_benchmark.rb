class AlertEnergyAnnualVersusBenchmark < AlertAnalysisBase
  include Logging
  attr_reader :last_year_kwh, :last_year_£, :last_year_co2, :last_year_co2_tonnes
  attr_reader :one_year_energy_per_pupil_kwh, :one_year_energy_per_pupil_£, :one_year_energy_per_pupil_co2
  attr_reader :one_year_energy_per_floor_area_kwh, :one_year_energy_per_floor_area_£, :one_year_energy_per_floor_area_co2
  attr_reader :percent_difference_from_average_per_pupil, :percent_difference_adjective
  attr_reader :simple_percent_difference_adjective, :summary

  def initialize(school)
    super(school, :annualenergybenchmark)
    @relevance = :relevant
  end

  def self.template_variables
    specific = {'Overall annual energy' => TEMPLATE_VARIABLES}
    specific.merge(self.superclass.template_variables)
  end

  def timescale
    'year'
  end

  def enough_data
    @school.all_aggregate_meters.all?{ |meter| meter.amr_data.days_valid_data > 364 } ? :enough : :not_enough
  end

  def no_single_aggregate_meter
    true
  end

  def maximum_alert_date
    @school.all_aggregate_meters.map { |meter| meter.amr_data.end_date }.min
  end

  TEMPLATE_VARIABLES = {
    last_year_kwh: {
      description: 'Last years energy consumption - kwh',
      units:  {kwh: :electricity},
      benchmark_code: 'klyr'
    },
    last_year_£: {
      description: 'Last years energy consumption - £ including differential tariff',
      units:  {£: :electricity},
      benchmark_code: '£lyr'
    },
    last_year_co2: {
      description: 'Last years energy CO2 kg',
      units:  :co2,
      benchmark_code: 'co2y'
    },
    last_year_co2_tonnes: {
      description: 'Last years energy CO2 tonnes',
      units:  :co2t,
      benchmark_code: 'co2y'
    },
    one_year_energy_per_pupil_kwh: {
      description: 'Per pupil annual energy usage - kwh',
      units:  :kwh,
      benchmark_code: 'kpup'
    },
    one_year_energy_per_pupil_£: {
      description: 'Per pupil annual energy usage - £',
      units:  :£,
      benchmark_code: '£pup'
    },
    one_year_energy_per_pupil_co2: {
      description: 'Per pupil annual energy usage - co2',
      units:  :co2,
      benchmark_code: 'cpup'
    },
    one_year_energy_per_floor_area_kwh: {
      description: 'Per floor area annual energy usage - kwh',
      units:  :kwh,
      benchmark_code: 'kfla'
    },
    one_year_energy_per_floor_area_£: {
      description: 'Per floor area annual energy usage - £',
      units:  :£,
      benchmark_code: '£fla'
    },
    one_year_energy_per_floor_area_co2: {
      description: 'Per floor area annual energy usage - co2',
      units:  :co2,
      benchmark_code: 'cfla'
    },
    percent_difference_from_average_per_pupil: {
      description: 'Percent difference from average',
      units:  :relative_percent,
      benchmark_code: 'pp%d'
    },
    percent_difference_adjective: {
      description: 'Adjective relative to average: above, signifantly above, about',
      units: String
    },
    simple_percent_difference_adjective:  {
      description: 'Adjective relative to average: above, about, below',
      units: String
    },
    summary: {
      description: 'Description: £spend/yr',
      units: String
    }
  }

  def calculate(asof_date)
    electricity_benchmark_alert     = calculate_alert(AlertElectricityAnnualVersusBenchmark, asof_date)
    gas_benchmark_alert             = calculate_alert(AlertGasAnnualVersusBenchmark, asof_date)
    storage_header_benchmark_alert  = calculate_alert(AlertStorageHeaterAnnualVersusBenchmark, asof_date)

    valid_alerts = [electricity_benchmark_alert, gas_benchmark_alert, storage_header_benchmark_alert].compact

    raise EnergySparksNotEnoughDataException, 'No valid annual electricity, gas or storage heater data - assuming less than one years meter data' if valid_alerts.empty?
    
    @last_year_kwh = valid_alerts.map { |alert| alert.last_year_kwh }.sum
    @last_year_£   = valid_alerts.map { |alert| alert.last_year_£ }.sum
    @last_year_co2 = valid_alerts.map { |alert| alert.last_year_co2 }.sum
    @last_year_co2_tonnes = @last_year_co2 / 1000.0

    @one_year_energy_per_pupil_kwh        = @last_year_kwh / @school.number_of_pupils
    @one_year_energy_per_floor_area_kwh   = @last_year_kwh / @school.floor_area

    @one_year_energy_per_pupil_£      = @last_year_£ / @school.number_of_pupils
    @one_year_energy_per_floor_area_£ = @last_year_£ / @school.floor_area

    @one_year_energy_per_pupil_co2      = @last_year_co2 / @school.number_of_pupils
    @one_year_energy_per_floor_area_co2 = @last_year_co2 / @school.floor_area

    @per_pupil_energy_benchmark_£ = BenchmarkMetrics.benchmark_energy_usage_£_per_pupil(:benchmark, @school)
    @per_pupil_energy_exemplar_£ = BenchmarkMetrics.benchmark_energy_usage_£_per_pupil(:exemplar, @school)

    @percent_difference_from_average_per_pupil = percent_change(@per_pupil_energy_benchmark_£, @one_year_energy_per_pupil_£)

    @percent_difference_adjective = Adjective.relative(@percent_difference_from_average_per_pupil, :relative_to_1)
    @simple_percent_difference_adjective = Adjective.relative(@percent_difference_from_average_per_pupil, :simple_relative_to_1)

    @summary  = summary_text

    if valid_alerts.length == 1
      @rating = valid_alerts[0].rating
    else
      # exemplar = 10.0, 20% worse than average = 0.0
      @rating = calculate_rating_from_range(@per_pupil_energy_exemplar_£, @per_pupil_energy_benchmark_£ * 1.2, @one_year_energy_per_pupil_£)
    end
  end
  alias_method :analyse_private, :calculate

  private def summary_text
    FormatEnergyUnit.format(:£, @last_year_£, :text) + 'pa'
    # , ' + 
    # FormatEnergyUnit.format(:percent, @percent_difference_from_average_per_pupil, :text) + ' ' +
    # @simple_percent_difference_adjective + ' average'
  end
  
  private def calculate_alert(alert_class, asof_date)
    alert = alert_class.new(@school)
    return nil unless alert.valid_alert?
    alert.analyse(asof_date)
    return nil unless alert.make_available_to_users?
    alert
  end
end