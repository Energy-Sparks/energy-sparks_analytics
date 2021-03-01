FactoryBot.define do
  factory :amr_data, class: "AMRData" do
    transient do
      type        { :gas }
    end

    initialize_with{ new(type) }

    after(:build) do |data|
      data.add(Date.today, build(:one_day_amr_reading) )
    end

  end
end
