# frozen_string_literal: true

FactoryBot.define do
  factory :meter_collection, class: 'MeterCollection' do
    transient do
      start_date              { Date.yesterday - 7 }
      end_date                { Date.yesterday }
      school                  { build(:school) }
      holidays                { build(:holidays, :with_academic_year) }
      temperatures            { build(:temperatures, :with_days, start_date: start_date, end_date: end_date) }
      solar_pv                { build(:solar_pv, :with_days, start_date: start_date, end_date: end_date) }
      grid_carbon_intensity   { build(:grid_carbon_intensity, :with_days, start_date: start_date, end_date: end_date) }
      pseudo_meter_attributes { {} }
      solar_irradiation       { nil }
    end

    initialize_with do
      new(school,
          holidays: holidays, temperatures: temperatures,
          solar_irradiation: solar_irradiation, solar_pv: solar_pv,
          grid_carbon_intensity: grid_carbon_intensity,
          pseudo_meter_attributes: pseudo_meter_attributes)
    end

    trait :with_electricity_meter do
      after(:build) do |meter_collection, evaluator|
        amr_data = build(:amr_data, :with_date_range, start_date: evaluator.start_date, end_date: evaluator.end_date)
        meter = build(:meter, meter_collection: meter_collection, type: :electricity, amr_data: amr_data)
        meter_collection.add_electricity_meter(meter)
      end
    end

    trait :with_gas_meter do
      after(:build) do |meter_collection, evaluator|
        amr_data = build(:amr_data, :with_date_range, start_date: evaluator.start_date, end_date: evaluator.end_date)
        meter = build(:meter, meter_collection: meter_collection, type: :gas, amr_data: amr_data)
        meter_collection.add_heat_meter(meter)
      end
    end

    trait :with_electricity_and_gas_meters do
      with_electricity_meter
      with_gas_meter
    end

    trait :with_aggregate_meter do
      transient do
        fuel_type { :electricity }
      end
      after(:build) do |meter_collection, evaluator|
        amr_data = build(:amr_data, :with_date_range, start_date: evaluator.start_date, end_date: evaluator.end_date)
        meter = build(:meter, meter_collection: meter_collection, type: evaluator.fuel_type, amr_data: amr_data)
        meter_collection.set_aggregate_meter(evaluator.fuel_type, meter)
      end
    end

    trait :with_electricity_meters do
      transient do
        meters { [] }
      end
      after(:build) do |meter_collection, evaluator|
        evaluator.meters.each do |m|
          meter_collection.add_electricity_meter(m)
        end
      end
    end
  end
end
