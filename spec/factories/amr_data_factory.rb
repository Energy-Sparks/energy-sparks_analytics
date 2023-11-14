# frozen_string_literal: true

FactoryBot.define do
  factory :amr_data, class: 'AMRData' do
    transient do
      type { :electricity }
    end

    initialize_with { new(type) }

    trait :single_day do
      after(:build) do |data|
        data.add(Date.today, build(:one_day_amr_reading))
      end
    end

    trait :with_date_range do
      transient do
        start_date   { Date.yesterday - 7 }
        end_date     { Date.yesterday }
        kwh_data_x48 { Array.new(48) { rand(0.0..1.0).round(2) } }
      end

      after(:build) do |amr_data, evaluator|
        (evaluator.start_date..evaluator.end_date).each do |date|
          reading = build(:one_day_amr_reading,
                          date: date,
                          type: 'ORIG',
                          substitute_date: nil,
                          upload_datetime: DateTime.now,
                          kwh_data_x48: evaluator.kwh_data_x48)
          amr_data.add(date, reading)
        end
      end
    end

    trait :with_days do
      transient do
        day_count { 7 }
        end_date { Date.today }
        kwh_data_x48 { nil }
      end

      after(:build) do |amr_data, evaluator|
        evaluator.day_count.times do |n|
          date = evaluator.end_date - n
          reading = if evaluator.kwh_data_x48.nil?
                      build(:one_day_amr_reading, date: date)
                    else
                      build(:one_day_amr_reading, date: date, kwh_data_x48: evaluator.kwh_data_x48)
                    end
          amr_data.add(date, reading)
        end
      end
    end
  end
end
