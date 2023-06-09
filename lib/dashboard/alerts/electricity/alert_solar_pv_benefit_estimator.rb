require 'minimization'
class AlertSolarPVBenefitEstimator < AlertElectricityOnlyBase
  attr_reader :optimum_kwp, :optimum_payback_years, :optimum_mains_reduction_percent
  attr_reader :one_year_saving_£current

  def initialize(school)
    super(school, :solarpvbenefitestimate)
    @relevance = (@relevance == :relevant && !@school.solar_pv_panels?) ? :relevant : :never_relevant
  end

  def self.template_variables
    specific = {'Solar PV Benefit Estimator' => TEMPLATE_VARIABLES}
    specific.merge(self.superclass.template_variables)
  end

  def timescale
    'year'
  end

  def enough_data
    aggregate_meter.amr_data.days_valid_data > 364 ? :enough : :not_enough
  end

  TEMPLATE_VARIABLES = {
    optimum_kwp: {
      description: 'Optimum PV capacity for school (kWp)',
      units:  :kwp,
      benchmark_code: 'opvk'
    },
    optimum_payback_years: {
      description: 'Payback period of optimum number of panels',
      units:  :years,
      benchmark_code: 'opvy'
    },
    optimum_mains_reduction_percent: {
      description: 'Optimum: percent redcution in mains consumption',
      units:  :percent,
      benchmark_code: 'opvp'
    },
    one_year_saving_£current: {
      description: 'Saving at latest tariffs for optimum scenario',
      units:  :£current,
      benchmark_code: 'opv€'
    }
  }

  def calculate(asof_date)
    days_data = [aggregate_meter.amr_data.end_date, asof_date].min - aggregate_meter.amr_data.start_date
    raise EnergySparksNotEnoughDataException, "Only #{days_data.to_i} days meter data" unless days_data > 364

    scenarios, optimum_kwp = calculate_range_of_scenarios(asof_date)

    optimum_scenario = find_optimum_kwp(scenarios, round_optimum_kwp(optimum_kwp))
    promote_optimum_variables(optimum_scenario)

    @one_year_saving_£current = optimum_scenario[:total_annual_saving_£]
    savings_range = Range.new(@one_year_saving_£current, @one_year_saving_£current)
    set_savings_capital_costs_payback(savings_range, optimum_scenario[:capital_cost_£], optimum_scenario[:total_annual_saving_co2])

    @rating = 5.0
  end
  alias_method :analyse_private, :calculate

  private

  def promote_optimum_variables(optimum_scenario)
    @optimum_kwp                      = optimum_scenario[:kwp]
    @optimum_payback_years            = optimum_scenario[:payback_years]
    @optimum_mains_reduction_percent  = optimum_scenario[:reduction_in_mains_percent]
  end

  def calculate_range_of_scenarios(asof_date)
    scenarios = []
    optimum_kwp, optimum_payback_years = optimum_payback(asof_date)
    kwp_scenario_including_optimum(optimum_kwp).each do |kwp|
      kwh_data = calculate_solar_pv_benefit(asof_date, kwp)
      £_data = calculate_economic_benefit(kwh_data)
      scenarios.push(kwh_data.merge(£_data))
    end
    [scenarios, optimum_kwp]
  end

  def find_optimum_kwp(rows, optimum_kwp)
    rows.select{ |row| row[:kwp] == optimum_kwp }[0]
  end

  def round_optimum_kwp(kwp)
    (kwp * 2.0).round(0) / 2.0
  end

  def kwp_scenario_including_optimum(optimum_kwp)
    optimum = round_optimum_kwp(optimum_kwp)
    kwp_scenario_ranges.push(optimum).sort.uniq
  end

  def max_possible_kwp
    # 25% of floor area, 6m2 panels/kWp
    (@school.floor_area * 0.25) / 6.0
  end

  def kwp_scenario_ranges
    scenarios = []
    (0..8).each do |p|
      scenarios.push(2**p) if 2**p < max_possible_kwp
    end
    scenarios
  end

  def optimum_payback(asof_date)
    optimum = Minimiser.minimize(1, max_possible_kwp) {|kwp| payback(kwp, asof_date) }
    [optimum.x_minimum, optimum.f_minimum]
  end

  def payback(kwp, asof_date)
    kwh_data = calculate_solar_pv_benefit(asof_date, kwp)
    calculate_economic_benefit(kwh_data)[:payback_years]
  end

  def calculate_solar_pv_benefit(asof_date, kwp)
    start_date = asof_date - 365

    pv_panels = ConsumptionEstimator.new # (attributes(asof_date, kwp))
    kwh_totals = estimate_consumption(start_date, asof_date, kwp)

    kwh = existing_annual_kwh(start_date, asof_date)
    £ = existing_annual_£(start_date, asof_date)

    {
      kwp:                          kwp,
      panels:                       number_of_panels(kwp),
      area:                         panel_area_m2(number_of_panels(kwp)),
      existing_annual_kwh:          kwh,
      existing_annual_£:            £,
      new_mains_consumption_kwh:    kwh_totals[:new_mains_consumption],
      new_mains_consumption_£:      kwh_totals[:new_mains_consumption_£],
      reduction_in_mains_percent:   (kwh - kwh_totals[:new_mains_consumption]) / kwh,
      solar_consumed_onsite_kwh:    kwh_totals[:solar_consumed_onsite],
      exported_kwh:                 kwh_totals[:exported],
      solar_pv_output_kwh:          kwh_totals[:solar_pv_output],
      solar_pv_output_co2:          kwh_totals[:solar_pv_output] * blended_co2_per_kwh
    }
  end

  def estimate_consumption(start_date, asof_date, kwp)
    pv_panels.annual_predicted_pv_totals_fast(aggregate_meter.amr_data, @school, start_date, asof_date, kwp)
  end

  def existing_annual_kwh(start_date, end_date)
    aggregate_meter.amr_data.kwh_date_range(start_date, end_date)
  end

  def existing_annual_£(start_date, end_date)
    aggregate_meter.amr_data.kwh_date_range(start_date, end_date, :£current)
  end

  def pv_panels
    ConsumptionEstimator.new
  end

  def number_of_panels(kwp)
    # assume 300 Wp per panel
    (kwp / 0.300).round(0).to_i
  end

  def panel_area_m2(panels)
    (panels * 1.6 * 0.9).round(0)
  end

  def calculate_economic_benefit(kwh_data)
    new_mains_cost = kwh_data[:new_mains_consumption_£]
    old_mains_cost = kwh_data[:existing_annual_£]
    export_income  = kwh_data[:exported_kwh] * BenchmarkMetrics.pricing.solar_export_price

    mains_savings   = old_mains_cost - new_mains_cost
    saving          = mains_savings  + export_income

    capital_cost    = capital_costs(kwh_data[:kwp])
    payback         = capital_cost / saving

    {
      old_mains_cost_£:         old_mains_cost,
      new_mains_cost_£:         new_mains_cost,
      export_income_£:          export_income,
      mains_savings_£:          mains_savings,
      total_annual_saving_£:    saving,
      total_annual_saving_co2:  kwh_data[:solar_pv_output_co2],
      capital_cost_£:           capital_cost,
      payback_years:            payback
    }
  end

  def capital_costs(kwp)
    # using analysis of ebay offerings (x20)
    # pending feedback to request (28Oct2019) for feedback on
    # real prices from BWCE and FreCo
    # old value: kwp == 0.0 ? 0.0 : (850.0 + 1200.0 * kwp)
    # PH 18Nov2019: reduced cost of larger installations following advice from PC/BWCE
    kwp == 0.0 ? 0.0 : (-0.8947 * kwp**2 + 793.86 * kwp + 1600)
  end

  def attributes(asof_date, kwp)
    [
      {
        start_date:         asof_date - 365,
        kwp:                kwp,
        orientation:        0,
        tilt:               30,
        shading:            0,
        fit_£_per_kwh:      0.05
      }
    ]
  end
end
