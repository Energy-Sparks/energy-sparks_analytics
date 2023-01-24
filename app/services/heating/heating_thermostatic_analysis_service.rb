# frozen_string_literal: true

module Heating
  class HeatingThermostaticAnalysisService
    attr_reader :aggregated_heat_meters

    def initialize(aggregated_heat_meters:)
      @aggregated_heat_meters = aggregated_heat_meters
    end

    def create_model
      OpenStruct.new(
        r2: r2,
        insulation_hotwater_heat_loss_estimate_kwh: insulation_hotwater_heat_loss_estimate_kwh,
        insulation_hotwater_heat_loss_estimate_£: insulation_hotwater_heat_loss_estimate_£
      )
    end

    private

    def latest_blended_tariff_£_per_kwh
      aggregated_heat_meters.amr_data.current_tariff_rate_£_per_kwh
    end

    def insulation_hotwater_heat_loss_estimate_£
      insulation_hotwater_heat_loss_estimate_kwh * latest_blended_tariff_£_per_kwh
    end

    def insulation_hotwater_heat_loss_estimate_kwh
      loss_kwh, percent_loss = heating_model.hot_water_poor_insulation_cost_kwh(one_year_before_last_meter_date, last_meter_date)
      loss_kwh
    end

  def one_year_before_last_meter_date
    [last_meter_date - 364, aggregated_heat_meters.amr_data.start_date].max
  end

  def last_meter_date
    aggregated_heat_meters.amr_data.end_date
  end



    # def hot_water_annual_loss_kwh
    #   return nil if aggregated_heat_meters.heating_only?
    # end

    def calculate_heating_model
      # Use simple_regression_temperature rather than best model for the explanation
      # otherwise the chart is too complicated for most
      # users to understand if the thermally massive model is used
      start_date = [aggregated_heat_meters.amr_data.end_date - 364, aggregated_heat_meters.amr_data.start_date].max
      last_year = SchoolDatePeriod.new(:analysis, 'validate amr', start_date, aggregated_heat_meters.amr_data.end_date)
      aggregated_heat_meters.heating_model(last_year, :simple_regression_temperature)
    end

    def heating_model
      @heating_model ||= calculate_heating_model
    end

    def r2
      heating_model.average_heating_school_day_r2
    end
  end
end
