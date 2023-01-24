# frozen_string_literal: true

module Heating
  class HeatingThermostaticAnalysisService
    attr_reader :aggregated_heat_meters

    def initialize(aggregated_heat_meters:)
      @aggregated_heat_meters = aggregated_heat_meters
    end

    def create_model
      OpenStruct.new(
        r2: r2
      )
    end

    private

    # def insulation_hotwater_heat_loss_estimate_kwh
    #   return nil if meter.heating_only?

    #   loss_kwh, percent_loss = heating_model.hot_water_poor_insulation_cost_kwh(one_year_before_last_meter_date, last_meter_date)
    #   loss_kwh
    # end

    def calculate_heating_model(model_type:  :best)
      start_date = [aggregated_heat_meters.amr_data.end_date - 364, aggregated_heat_meters.amr_data.start_date].max
      last_year = SchoolDatePeriod.new(:analysis, 'validate amr', start_date, aggregated_heat_meters.amr_data.end_date)
      aggregated_heat_meters.heating_model(last_year, model_type)
    end

    def heating_model
      @heating_model ||= calculate_heating_model
    end

    def r2
      heating_model.average_heating_school_day_r2
    end
  end
end
