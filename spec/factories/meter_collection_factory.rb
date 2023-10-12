FactoryBot.define do
  factory :meter_collection, class: MeterCollection do
    transient do
      school                  { build(:school) }
      holidays                { build(:holidays, :with_academic_year) }
      temperatures            { build(:temperatures) }
      solar_pv                { build(:solar_pv) }
      grid_carbon_intensity   { build(:grid_carbon_intensity) }
      pseudo_meter_attributes { {} }
      solar_irradiation       { nil }
    end

    initialize_with{ new(school,
      holidays: holidays, temperatures: temperatures,
      solar_irradiation: solar_irradiation, solar_pv: solar_pv,
      grid_carbon_intensity: grid_carbon_intensity,
      pseudo_meter_attributes: pseudo_meter_attributes) }

    trait :with_electricity_meter do
      transient do
        amr_data          { build(:amr_data, :with_date_range) }
      end

      after(:build) do |meter_collection, evaluator|
        meter = build(:meter, meter_collection: meter_collection, type: :electricity, amr_data: evaluator.amr_data)
        meter_collection.add_electricity_meter(meter)
      end
    end

    trait :with_gas_meter do
      transient do
        amr_data          { build(:amr_data, :with_date_range) }
      end

      after(:build) do |meter_collection, evaluator|
        meter = build(:meter, meter_collection: meter_collection, type: :gas, amr_data: evaluator.amr_data)
        meter_collection.add_heat_meter(meter)
      end
    end

    trait :with_electricity_and_gas_meters do
      with_electricity_meter
      with_gas_meter
    end
  end
end
