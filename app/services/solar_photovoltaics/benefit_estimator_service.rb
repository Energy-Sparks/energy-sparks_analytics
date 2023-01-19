# frozen_string_literal: true

module SolarPhotovoltaics
  class BenefitEstimatorService
    attr_reader :solar_pv_scenario_table, :one_year_saving_£current, :scenarios

    def initialize(school:, asof_date: Date.today)
      @school = school
      raise if @school.solar_pv_panels?
      raise if !enough_data?

      @asof_date = asof_date
      @benefit_scenarios_collection = []
    end

    def calculate_benefits!(use_max_meter_date_if_less_than_asof_date: false)
      @max_asofdate = aggregated_electricity_meters.amr_data.end_date
      date = use_max_meter_date_if_less_than_asof_date ? [maximum_alert_date, asof_date].min : @asof_date
      calculate(date) if @analysis_date.nil? || @analysis_date != date # only call once per date
    end

    private

    def enough_data?
      aggregated_electricity_meters.amr_data.days_valid_data > 364
    end

    def aggregated_electricity_meters
      @aggregated_electricity_meters ||= @school.aggregated_electricity_meters
    end

    def calculate(calculate_date)
      days_data = [aggregated_electricity_meters.amr_data.end_date, calculate_date].min - aggregated_electricity_meters.amr_data.start_date
      raise EnergySparksNotEnoughDataException, "Only #{days_data.to_i} days meter data" unless days_data > 364

      @scenarios, optimum_kwp = calculate_range_of_scenarios(calculate_date)

      optimum_scenario = find_optimum_kwp(@scenarios, round_optimum_kwp(optimum_kwp))
      promote_optimum_variables(optimum_scenario)

      @one_year_saving_£current = optimum_scenario[:total_annual_saving_£]
      savings_range = Range.new(@one_year_saving_£current, @one_year_saving_£current)
      set_savings_capital_costs_payback(
        savings_range,
        optimum_scenario[:capital_cost_£],
        optimum_scenario[:total_annual_saving_co2]
      )
    end

    def calculate_range_of_scenarios(calculate_date)
      scenarios = []
      optimum_kwp, optimum_payback_years = optimum_payback(calculate_date)
      kwp_scenario_including_optimum(optimum_kwp).each do |kwp|
        kwh_data = calculate_solar_pv_benefit(calculate_date, kwp)
        £_data = calculate_economic_benefit(kwh_data)
        scenarios.push(kwh_data.merge(£_data))
      end
      [scenarios, optimum_kwp]
    end

    def kwp_scenario_including_optimum(optimum_kwp)
      optimum = round_optimum_kwp(optimum_kwp)
      kwp_scenario_ranges.push(optimum).sort.uniq
    end

    def round_optimum_kwp(kwp)
      (kwp * 2.0).round(0) / 2.0
    end

    def kwp_scenario_ranges
      (0..8).each_with_object([]) do |p, capacity_rows|
        capacity_rows.push(2**p) if 2**p < max_possible_kwp
      end
    end

    def find_optimum_kwp(rows, optimum_kwp)
      rows.select { |row| row[:kwp] == optimum_kwp }[0]
    end

    def promote_optimum_variables(optimum_scenario)
      @optimum_kwp                      = optimum_scenario[:kwp]
      @optimum_payback_years            = optimum_scenario[:payback_years]
      @optimum_mains_reduction_percent  = optimum_scenario[:reduction_in_mains_percent]
    end

    def set_savings_capital_costs_payback(one_year_saving_£, capital_cost, one_year_saving_co2)
      one_year_saving_£ = Range.new(one_year_saving_£, one_year_saving_£) if one_year_saving_£.is_a?(Float)

      @one_year_saving_co2 = one_year_saving_co2
      @ten_year_saving_co2 = one_year_saving_co2 * 10.0

      capital_cost = Range.new(capital_cost, capital_cost) if capital_cost.is_a?(Float)
      @capital_cost = capital_cost
      @average_capital_cost = capital_cost.nil? ? 0.0 : ((capital_cost.first + capital_cost.last) / 2.0)

      @one_year_saving_£ = one_year_saving_£
      @ten_year_saving_£ = one_year_saving_£.nil? ? 0.0 : Range.new(one_year_saving_£.first * 10.0, one_year_saving_£.last * 10.0)
      @average_one_year_saving_£ = one_year_saving_£.nil? ? 0.0 : ((one_year_saving_£.first + one_year_saving_£.last) / 2.0)
      @average_ten_year_saving_£ = @average_one_year_saving_£ * 10.0

      @average_payback_years = @one_year_saving_£.nil? || @one_year_saving_£ == 0.0 || @average_capital_cost.nil? ? 0.0 : @average_capital_cost / @average_one_year_saving_£
    end

    def optimum_payback(asof_date)
      optimum = Minimiser.minimize(1, max_possible_kwp) { |kwp| payback(kwp, asof_date) }
      [optimum.x_minimum, optimum.f_minimum]
    end

    def payback(kwp, asof_date)
      kwh_data = calculate_solar_pv_benefit(asof_date, kwp)
      calculate_economic_benefit(kwh_data)[:payback_years]
    end

    def calculate_solar_pv_benefit(asof_date, kwp)
      start_date = asof_date - 365

      pv_panels = SolarPVPanelsNewBenefit.new # (attributes(asof_date, kwp))

      kwh_totals = pv_panels.annual_predicted_pv_totals_fast(aggregated_electricity_meters.amr_data, @school, start_date, asof_date, kwp)

      kwh = aggregated_electricity_meters.amr_data.kwh_date_range(start_date, asof_date)

      £ = aggregated_electricity_meters.amr_data.kwh_date_range(start_date, asof_date, :£current)

      {
        kwp: kwp,
        panels: number_of_panels(kwp),
        area: panel_area_m2(number_of_panels(kwp)),
        existing_annual_kwh: kwh,
        existing_annual_£: £,
        new_mains_consumption_kwh: kwh_totals[:new_mains_consumption],
        new_mains_consumption_£: kwh_totals[:new_mains_consumption_£],
        reduction_in_mains_percent: (kwh - kwh_totals[:new_mains_consumption]) / kwh,
        solar_consumed_onsite_kwh: kwh_totals[:solar_consumed_onsite],
        exported_kwh: kwh_totals[:exported],
        solar_pv_output_kwh: kwh_totals[:solar_pv_output],
        solar_pv_output_co2: kwh_totals[:solar_pv_output] * ::Baseload::BlendedRateCalculator.new(aggregated_electricity_meters).blended_co2_per_kwh # blended_co2_per_kwh
      }
    end

    def calculate_economic_benefit(kwh_data)
      new_mains_cost = kwh_data[:new_mains_consumption_£]
      old_mains_cost = kwh_data[:existing_annual_£]
      export_income  = kwh_data[:exported_kwh] * BenchmarkMetrics::SOLAR_EXPORT_PRICE

      mains_savings   = old_mains_cost - new_mains_cost
      saving          = mains_savings + export_income

      capital_cost    = capital_costs(kwh_data[:kwp])
      payback         = capital_cost / saving

      {
        old_mains_cost_£: old_mains_cost,
        new_mains_cost_£: new_mains_cost,
        export_income_£: export_income,
        mains_savings_£: mains_savings,
        total_annual_saving_£: saving,
        total_annual_saving_co2: kwh_data[:solar_pv_output_co2],
        capital_cost_£: capital_cost,
        payback_years: payback
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

    def number_of_panels(kwp)
      # assume 300 Wp per panel
      (kwp / 0.300).round(0).to_i
    end

    def panel_area_m2(panels)
      (panels * 1.6 * 0.9).round(0)
    end

    def max_possible_kwp
      # 25% of floor area, 6m2 panels/kWp
      (@school.floor_area * 0.25) / 6.0
    end
  end
end
