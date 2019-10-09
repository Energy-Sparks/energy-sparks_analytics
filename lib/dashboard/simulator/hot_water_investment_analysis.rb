module AnalyseHeatingAndHotWater
  class HotWaterInvestmentAnalysis
    PUPILS_PER_POINT_OF_USE_HOTWATER_HEATER = 20.0
    STANDING_LOSS_FROM_ELECTRIC_WATER_HEATER_KWH_PER_DAY = 0.35
    CAPITAL_COST_POU_ELECTRIC_HEATER = 200.0
    INSTALL_COST_POU_ELECTRIC_HEATER = 200.0
    def initialize(school)
      @school = school
      @hot_water_model = HotwaterModel.new(@school)
    end

    def analyse_annual
      current = existing_gas_estimates
      {
        existing_gas:           current,
        gas_better_control:     calculate_saving(current, gas_better_control),
        point_of_use_electric:  calculate_saving(current, point_of_use_hotwater_economics)
      }
    end

    private def calculate_saving(base_line, proposal)
      saving_kwh, saving_kwh_percent  = saving_and_percent(base_line[:kwh], proposal[:kwh])
      saving_£, saving_£_percent      = saving_and_percent(base_line[:£],   proposal[:£])
      saving_co2, saving_co2_percent  = saving_and_percent(base_line[:co2], proposal[:co2])
      payback_years = proposal[:capex] == 0.0 ? 0.0 : (proposal[:capex] / saving_£)
      {
        saving_kwh:         saving_kwh,
        saving_kwh_percent: saving_kwh_percent,
        saving_£:           saving_£,
        saving_£_percent:   saving_£_percent,
        saving_co2:         saving_co2,
        saving_co2_percent: saving_co2_percent,
        payback_years:      payback_years
      }.merge(proposal)
    end

    private def saving_and_percent(baseline, proposal)
      saving = baseline - proposal
      [saving, saving / baseline]
    end

    private def existing_gas_estimates
      total_kwh = @hot_water_model.annual_hotwater_kwh_estimate
      {
        kwh:    total_kwh,
        £:      total_kwh * BenchmarkMetrics::GAS_PRICE,
        co2:    total_kwh * EnergyEquivalences::UK_GAS_CO2_KG_KWH,
        capex:  0.0
      }
    end

    private def gas_better_control
      total_kwh = @hot_water_model.annual_hotwater_kwh_estimate_better_control
      {
        kwh:    total_kwh,
        £:      total_kwh * BenchmarkMetrics::GAS_PRICE,
        co2:    total_kwh * EnergyEquivalences::UK_GAS_CO2_KG_KWH,
        capex:  0.0
      }
    end

    private def point_of_use_hotwater_economics
      _hw_kwh, _standing_loss_kwh, total_kwh = self.class.annual_point_of_use_electricity_meter_kwh(@school.number_of_pupils)
      {
        kwh:    total_kwh,
        £:      total_kwh * BenchmarkMetrics::ELECTRICITY_PRICE,
        co2:    total_kwh * BenchmarkMetrics::LONG_TERM_ELECTRICITY_CO2_KG_PER_KWH,
        capex:  point_of_use_electric_heaters_capex
      }
    end

    private def point_of_use_electric_heaters_capex
      number_of_heaters = self.class.estimated_number_pou_heaters(@school.number_of_pupils)
      number_of_heaters * (CAPITAL_COST_POU_ELECTRIC_HEATER + INSTALL_COST_POU_ELECTRIC_HEATER)
    end

    def self.estimated_number_pou_heaters(pupils, pupils_per_point_of_use_hotwater_heater = PUPILS_PER_POINT_OF_USE_HOTWATER_HEATER)
      (pupils / pupils_per_point_of_use_hotwater_heater).ceil
    end

    def self.annual_point_of_use_electricity_meter_kwh(pupils, pupils_per_point_of_use_hotwater_heater = PUPILS_PER_POINT_OF_USE_HOTWATER_HEATER)
      standing_loss = estimated_number_pou_heaters(pupils) * STANDING_LOSS_FROM_ELECTRIC_WATER_HEATER_KWH_PER_DAY * 365
      hot_water_usage = HotwaterModel.benchmark_annual_pupil_kwh * pupils
      [hot_water_usage, standing_loss, hot_water_usage + standing_loss]
    end
  end
end