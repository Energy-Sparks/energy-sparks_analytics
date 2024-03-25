# frozen_string_literal: true

FactoryBot.define do
  factory :target_school, class: 'TargetSchool' do
    transient do
      calculation_type { :day }
      start_date { Date.yesterday }
      end_date { Date.today }
      meter_collection do
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
        meter_collection
      end
    end

    initialize_with do
      AggregateDataService.new(meter_collection).aggregate_heat_and_electricity_meters
      new(meter_collection, calculation_type)
    end
  end
end
