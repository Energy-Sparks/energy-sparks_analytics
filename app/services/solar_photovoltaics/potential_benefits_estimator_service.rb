# frozen_string_literal: true

# rubocop:disable Naming/VariableName, Metrics/ClassLength
module SolarPhotovoltaics
  class PotentialBenefitsEstimatorService
    attr_reader :scenarios, :optimum_kwp, :optimum_payback_years, :optimum_mains_reduction_percent

    def initialize(meter_collection:, asof_date: Date.today)
      @meter_collection = meter_collection
      raise if @meter_collection.solar_pv_panels?

      @asof_date = asof_date
    end

    def create_model
      calculate_potential_benefits_estimates

      OpenStruct.new(
        optimum_kwp: optimum_kwp,
        optimum_payback_years: optimum_payback_years,
        optimum_mains_reduction_percent: optimum_mains_reduction_percent,
        scenarios: @scenarios
      )
    end

    private

    def calculate_potential_benefits_estimates
      # (use_max_meter_date_if_less_than_asof_date: false)
      # @max_asofdate = aggregated_electricity_meters.amr_data.end_date
      # date = use_max_meter_date_if_less_than_asof_date ? [maximum_alert_date, asof_date].min : @asof_date
      date = @asof_date

      calculate_optimum_payback_for(date)
      calculate_range_of_scenarios_for(date)
      calculate_savings
    end

    def aggregated_electricity_meters
      @aggregated_electricity_meters ||= @meter_collection.aggregated_electricity_meters
    end

    # rubocop:disable Metrics/MethodLength
    def calculate_savings
      optimum_scenario = find_optimum_kwp(@scenarios, round_optimum_kwp(optimum_kwp))
      @optimum_kwp = optimum_scenario[:kwp]
      @optimum_payback_years = optimum_scenario[:payback_years]
      @optimum_mains_reduction_percent = optimum_scenario[:reduction_in_mains_percent]
      @one_year_saving_£current = optimum_scenario[:total_annual_saving_£]

      savings_range = Range.new(@one_year_saving_£current, @one_year_saving_£current)
      set_savings_capital_costs_payback(
        savings_range,
        optimum_scenario[:capital_cost_£],
        optimum_scenario[:total_annual_saving_co2]
      )
    end
    # rubocop:enable Metrics/MethodLength

    def calculate_range_of_scenarios_for(date)
      @scenarios = []

      kwp_scenario_including_optimum(optimum_kwp).each do |kwp|
        solar_pv_benefit_results = calculate_solar_pv_benefit(date, kwp)
        economic_benefit_results = calculate_economic_benefit(solar_pv_benefit_results)

        @scenarios << OpenStruct.new(
          solar_pv_benefit_results.merge(economic_benefit_results)
        )
      end
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

    # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity, Layout/LineLength, Lint/FloatComparison
    def set_savings_capital_costs_payback(one_year_saving_£, capital_cost, one_year_saving_co2)
      # Note: this code is copied from existing code in AlertAnalysisBase and needs refactoring (see rubocop comment)
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
    # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity, Layout/LineLength, Lint/FloatComparison

    def calculate_optimum_payback_for(date)
      optimum = Minimiser.minimize(1, max_possible_kwp) { |kwp| payback(kwp, date) }
      @optimum_kwp = optimum.x_minimum
      @optimum_payback_years = optimum.f_minimum
    end

    def payback(kwp, date)
      kwh_data = calculate_solar_pv_benefit(date, kwp)
      calculate_economic_benefit(kwh_data)[:payback_years]
    end

    # rubocop:disable Metrics/MethodLength, Metrics/AbcSize, Layout/LineLength, Naming/VariableNumber
    def calculate_solar_pv_benefit(date, kwp)
      # Note: this code is copied from existing code in AlertSolarPVBenefitEstimator and needs refactoring (see rubocop comment)
      start_date = date - 365
      kwh_totals = pv_panels.annual_predicted_pv_totals_fast(aggregated_electricity_meters.amr_data, @meter_collection, start_date, date, kwp)

      kwh = aggregated_electricity_meters.amr_data.kwh_date_range(start_date, date)
      £ = aggregated_electricity_meters.amr_data.kwh_date_range(start_date, date, :£current)

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
        solar_pv_output_co2: kwh_totals[:solar_pv_output] * blended_co2_per_kwh
      }
    end
    # rubocop:enable Metrics/MethodLength, Metrics/AbcSize, Layout/LineLength, Naming/VariableNumber

    def pv_panels
      SolarPVPanelsNewBenefit.new
    end

    def blended_co2_per_kwh
      @blended_co2_per_kwh ||= ::Baseload::BlendedRateCalculator.new(aggregated_electricity_meters).blended_co2_per_kwh
    end

    # rubocop:disable Metrics/MethodLength
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
    # rubocop:enable Metrics/MethodLength

    # rubocop:disable Lint/FloatComparison
    def capital_costs(kwp)
      # using analysis of ebay offerings (x20)
      # pending feedback to request (28Oct2019) for feedback on
      # real prices from BWCE and FreCo
      # old value: kwp == 0.0 ? 0.0 : (850.0 + 1200.0 * kwp)
      # PH 18Nov2019: reduced cost of larger installations following advice from PC/BWCE
      kwp == 0.0 ? 0.0 : (-0.8947 * kwp**2 + 793.86 * kwp + 1600)
    end
    # rubocop:enable Lint/FloatComparison

    def number_of_panels(kwp)
      # assume 300 Wp per panel
      (kwp / 0.300).round(0).to_i
    end

    def panel_area_m2(panels)
      (panels * 1.6 * 0.9).round(0)
    end

    def max_possible_kwp
      # 25% of floor area, 6m2 panels/kWp
      @max_possible_kwp ||= (@meter_collection.floor_area * 0.25) / 6.0
    end
  end
end
# rubocop:enable Naming/VariableName, Metrics/ClassLength
