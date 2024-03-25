# frozen_string_literal: true

require 'spec_helper'

describe AlertLayerUpPowerdownNovember2023ElectricityComparison do
  describe '#calculate' do
    it 'calculates' do
      start_date = Date.new(2022, 11, 1)
      end_date = Date.new(2023, 11, 30)
      meter_collection = build(:meter_collection, :with_aggregate_meter,
                               start_date: start_date, end_date: end_date,
                               pseudo_meter_attributes: {
                                 aggregated_electricity: {
                                   targeting_and_tracking: [{
                                     start_date: start_date,
                                     target: 0.95
                                   }]
                                 }
                               })
      meter = build(:meter, :with_flat_rate_tariffs,
                    meter_collection: meter_collection, type: :electricity,
                    amr_data: build(:amr_data, :with_date_range, start_date: start_date,
                                                                 end_date: end_date,
                                                                 kwh_data_x48: Array.new(48, 1)))
      meter_collection.add_electricity_meter(meter)
      AggregateDataService.new(meter_collection).aggregate_heat_and_electricity_meters

      # school = build(:school)
      school = TargetSchool.new(meter_collection, :day)
      # binding.pry
      alert = described_class.new(school)
      alert.analyse(Date.new(2023, 11, 30))
      p alert.current_period_kwh
      p alert.previous_period_kwh
    end
  end
end
