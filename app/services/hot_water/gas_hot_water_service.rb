# frozen_string_literal: true

module HotWater
  class GasHotWaterService
    def initialize(meter_collection:)
      @meter_collection = meter_collection
    end

    def create_model
      OpenStruct.new(
        investment_choices: investment_choices,
        hotwater_analysis: hotwater_analysis
      )
    end

    private

    def investment_analysis
      @investment_analysis ||= AnalyseHeatingAndHotWater::HotWaterInvestmentAnalysis.new(@meter_collection)
    end

    def day_type_data
      HotWaterDayTypeTableFormatting.new(@investment_analysis)
    end

    def investment_analysis_annual
      # Returns a hash of investment choices: existing gas, gas better control, and point of use electric
      investment_analysis.analyse_annual
    end

    def investment_choices
      investment_analysis_annual.each_with_object(OpenStruct.new) do |(type, values), investment_choices|
        investment_choices[type] = OpenStruct.new(values)
      end
    end

    def current_system_efficiency_percent
      investment_data[:existing_gas][:efficiency]
    end

    def hotwater_model
      @hotwater_model ||= investment_analysis.hotwater_model
    end

    def hotwater_analysis
      @hotwater_analysis ||= hotwater_model.daytype_breakdown_statistics
    end
  end
end
