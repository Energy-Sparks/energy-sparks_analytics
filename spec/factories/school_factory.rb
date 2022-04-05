FactoryBot.define do
  factory :school, class: "Dashboard::School" do
    transient do
      sequence(:name) { |n| "test #{n} school" }
      address         { '1 Station Road' }
      floor_area      { BigDecimal("1234.567") }
      sequence(:number_of_pupils)
      school_type     { :primary }
      area_name       { 'Bath' }
      sequence(:urn)
      postcode        { 'ab1 2cd' }
      activation_date { Date.today }
      created_at      { Date.today }
      latitude        { 51.509865 }
      longitude       { -0.118092 }
      data_enabled    { true }
    end

    initialize_with{ new(name: name, address: address, floor_area:
      floor_area, number_of_pupils: number_of_pupils,
      school_type: school_type, area_name: area_name,
      urn: urn, postcode: postcode, activation_date: activation_date,
      created_at: created_at, location: [latitude, longitude], data_enabled: data_enabled) }
  end
end
