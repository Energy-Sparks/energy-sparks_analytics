FactoryBot.define do
  factory :one_data_amr_reading, class: "OneDayAMRReading" do
    transient do
      sequence(:meter_id)   { |n| n }
      date                  { Date.today }
      type                  { 'ORIG' }
      substitute_date       { nil }
      upload_datetime       { DateTime.now }
      kwh_data_x48          { Array.new(48, 0.0) }
    end

    initialize_with{ new(meter_id, date, type, substitute_date,
      upload_datetime, kwh_data_x48)}
  end
end
