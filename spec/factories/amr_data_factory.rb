FactoryBot.define do
  factory :amr_data, class: "AMRData" do
    transient do
      type        { :electricity }
    end

    initialize_with{ new(type) }

    trait :single_day do
      after(:build) do |data|
        data.add(Date.today, build(:one_day_amr_reading) )
      end
    end

    trait :with_days do
      transient do
        day_count { 7 }
      end

      after(:build) do |amr_data, evaluator|
        evaluator.day_count.times do |n|
          date = Date.today - n
          amr_data.add(date, build(:one_day_amr_reading, date: date))
        end
      end
    end
  end
end
