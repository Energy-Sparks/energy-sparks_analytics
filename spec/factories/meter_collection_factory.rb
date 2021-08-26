FactoryBot.define do
  factory :meter_collection, class: MeterCollection do
    transient do
      school                  { build(:school) }
      holidays                { HolidayData.new }
      temperatures            { Temperatures.new('temperatures') }
      solar_pv                { SolarPV.new('solar pv') }
      grid_carbon_intensity   { GridCarbonIntensity.new }
      pseudo_meter_attributes { {} }
      solar_irradiation       { nil }
    end

    initialize_with{ new(school,
      holidays: holidays, temperatures: temperatures,
      solar_irradiation: solar_irradiation, solar_pv: solar_pv,
      grid_carbon_intensity: grid_carbon_intensity,
      pseudo_meter_attributes: pseudo_meter_attributes) }
  end
end
