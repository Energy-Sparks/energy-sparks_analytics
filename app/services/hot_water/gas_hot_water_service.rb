module HotWater
  class GasHotWaterService
    def initialize(meter_collection:)
      @meter_collection = meter_collection
    end

    def create_model
      OpenStruct.new(
        investment_data: OpenStruct.new(investment_data),
        hotwater_analysis: OpenStruct.new(hotwater_analysis)
      )
    end

    private

    def investment_analysis
      @investment_analysis ||= AnalyseHeatingAndHotWater::HotWaterInvestmentAnalysis.new(@meter_collection)
    end

    def day_type_data
      HotWaterDayTypeTableFormatting.new(@investment_analysis)
    end

    def investment_data
      @investment_data ||= investment_analysis.analyse_annual
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
