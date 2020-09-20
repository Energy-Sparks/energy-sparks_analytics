class AlertEnergyAnnualVersusBenchmark < AlertAnalysisBase
  include Logging
  attr_reader :last_year_kwh, :last_year_£, :last_year_co2, :last_year_co2_tonnes
  attr_reader :one_year_energy_per_pupil_kwh, :one_year_energy_per_pupil_£, :one_year_energy_per_pupil_co2
  attr_reader :one_year_energy_per_floor_area_kwh, :one_year_energy_per_floor_area_£, :one_year_energy_per_floor_area_co2
  attr_reader :percent_difference_from_average_per_pupil, :percent_difference_adjective
  attr_reader :simple_percent_difference_adjective, :summary, :trees_co2
  attr_reader :change_in_energy_use_since_joined_percent, :change_in_electricity_use_since_joined_percent
  attr_reader :change_in_gas_use_since_joined_percent, :change_in_storage_heater_use_since_joined_percent
  attr_reader :last_year_electricity_co2, :last_year_gas_co2
  attr_reader :last_year_storage_heater_co2, :last_year_solar_pv_co2

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
      benchmark_code: 'co2t'
    },
    last_year_electricity_co2: {
      description: 'Last years electricity CO2 kg',
      units:  :co2,
      benchmark_code: 'co2e'
    },
    last_year_gas_co2: {
      description: 'Last years gas CO2 kg',
      units:  :co2,
      benchmark_code: 'co2g'
    },
    last_year_storage_heater_co2: {
      description: 'Last years storage heater CO2 kg',
      units:  :co2,
      benchmark_code: 'co2h'
    },
    last_year_solar_pv_co2: {
      description: 'Last years solar CO2 kg',
      units:  :co2,
      benchmark_code: 'co2s'
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
    },
    trees_co2: {
      description: 'Number of trees (40 years) equivalence of CO2',
      units:  :tree
    },
    change_in_energy_use_since_joined_percent: {
      description: 'Percent change in energy use since joined (percent)',
      units:  :relative_percent,
      benchmark_code: 'csjp'
    },
    change_in_electricity_use_since_joined_percent: {
      description: 'Percent change in electricity use since joined (percent)',
      units:  :relative_percent,
      benchmark_code: 'esjp'
    },
    change_in_gas_use_since_joined_percent: {
      description: 'Percent change in gas use since joined (percent)',
      units:  :relative_percent,
      benchmark_code: 'gsjp'
    },
    change_in_storage_heater_use_since_joined_percent: {
      description: 'Percent change in storage_heater use since joined (percent)',
      units:  :relative_percent,
      benchmark_code: 'ssjp'
    },
  }

  def trees_electricity
    @school.electricity? ? EnergyConversions.new(@school).front_end_convert(:tree_co2_tree, timescale, :allelectricity_unmodified)[:equivalence] : 0.0
  end

  def trees_gas
    @school.gas? ? EnergyConversions.new(@school).front_end_convert(:tree_co2_tree, timescale, :gas)[:equivalence] : 0.0
  end

  def trees
    trees_electricity + trees_gas
  end

  def trees_description
    trees_numbers = trees.round(0).to_i
    "#{trees_numbers} trees"
  end

  def calculate(asof_date)
    electricity_benchmark_alert     = calculate_alert(AlertElectricityAnnualVersusBenchmark, asof_date)
    gas_benchmark_alert             = calculate_alert(AlertGasAnnualVersusBenchmark, asof_date)
    storage_header_benchmark_alert  = calculate_alert(AlertStorageHeaterAnnualVersusBenchmark, asof_date)

    valid_alerts = [electricity_benchmark_alert, gas_benchmark_alert, storage_header_benchmark_alert].compact

    raise EnergySparksNotEnoughDataException, 'No valid annual electricity, gas or storage heater data - assuming less than one years meter data' if valid_alerts.empty?
    
    @last_year_kwh = valid_alerts.map { |alert| alert.last_year_kwh }.sum
    @last_year_£   = valid_alerts.map { |alert| alert.last_year_£ }.sum
    
    pv = calculate_last_year_solar_pv_production_co2(asof_date)
    @last_year_solar_pv_co2       = pv
    @last_year_co2 = valid_alerts.map { |alert| alert.last_year_co2 }.sum + pv.to_f # coerse pv nil to 0.0
    @last_year_co2_tonnes = @last_year_co2 / 1000.0

    @last_year_electricity_co2    = electricity_benchmark_alert.last_year_co2     unless electricity_benchmark_alert.nil?
    @last_year_gas_co2            = gas_benchmark_alert.last_year_co2             unless gas_benchmark_alert.nil?
    @last_year_storage_heater_co2 = storage_header_benchmark_alert.last_year_co2  unless storage_header_benchmark_alert.nil?

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

    @trees_co2 = trees

    since_activation_date = calculate_change_since_activation_date(asof_date)
    unless since_activation_date.nil?
      @change_in_energy_use_since_joined_percent         = since_activation_date.dig(:aggregate, :change)
      @change_in_electricity_use_since_joined_percent    = since_activation_date.dig(:electricity, :change)
      @change_in_gas_use_since_joined_percent            = since_activation_date.dig(:gas, :change)
      @change_in_storage_heater_use_since_joined_percent = since_activation_date.dig(:storage_heater, :change)
    end

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

  # one off special, probably not for reuse elsewhere in the code
  private def calculate_change_since_activation_date(asof_date, data_type = :kwh)
    dates = comparison_dates(asof_date)
    return nil if dates.nil?

    results = @school.all_aggregate_meters.map{ |meter| [meter.meter_type, calculate_use(dates, meter, data_type)] }.to_h

    aggregate = {
      # map then sum to avoid statsample bug
      first_year: results.values.map{ |data| data[:first_year] }.sum,
      last_year:  results.values.map{ |data| data[:last_year]  }.sum,
    }
    aggregate[:change] = (aggregate[:last_year] - aggregate[:first_year])/aggregate[:first_year]
    results[:aggregate] = aggregate
    results
  end

  private def calculate_use(dates, meter, data_type)
    first_year = meter.amr_data.kwh_date_range(dates[:first_year].first, dates[:first_year].last, data_type)
    last_year  = meter.amr_data.kwh_date_range(dates[:last_year ].first, dates[:last_year ].last, data_type)
    {
      first_year: first_year,
      last_year:  last_year,
      change:     (last_year - first_year)/first_year # allow infinity
    }
  end

  private def comparison_dates(asof_date)
    first_combined_meter_date = @school.all_aggregate_meters.map { |meter| meter.amr_data.start_date }.max
    last_combined_meter_date  = @school.all_aggregate_meters.map { |meter| meter.amr_data.end_date }.min

    max_asofdate = [asof_date, last_combined_meter_date].min
    activated = activation_date.nil? ? creation_date : activation_date
    first_comparison_date = [activated, first_combined_meter_date].max

    comparison_possible = (max_asofdate - first_comparison_date) > 365 * 2
    return nil unless comparison_possible

    {
      first_year: first_comparison_date..(first_comparison_date + 364),
      last_year:  (max_asofdate - 364)..max_asofdate
    }
  end

  def calculate_last_year_solar_pv_production_co2(asof_date)
    return nil unless @school.solar_pv_panels?
    scalar = ScalarkWhCO2CostValues.new(@school)
    last_year     = - scalar.aggregate_value({year:  0}, :solar_pv, :co2, { asof_date: asof_date} )
    last_year
=begin
    previous_year = - scalar.aggregate_value({year: -1}, :solar_pv, :co2)
    {
      last_year:      last_year,
      previous_year:  previous_year,
      change:         (last_year - previous_year) / previous_year
    }
=end
  end
end