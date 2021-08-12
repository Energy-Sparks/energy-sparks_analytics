FactoryBot.define do
  factory :holidays, class: Holidays do

    trait :with_academic_year do
      transient do
        country { nil }
        year    { Date.today.year }
      end

      initialize_with {
        data = HolidayData.new
        data.push(
          build(:holiday, name: "Autumn",
            start_date: Date.new(year - 1, 10, 17), end_date: Date.new(year - 1, 11, 1))
        )
        data.push(
          build(:holiday, name: "Spring",
            start_date: Date.new(year, 2, 13), end_date: Date.new(year, 2, 21))
        )
        data.push(
          build(:holiday, name: "Summer",
            start_date: Date.new(year, 5, 29), end_date: Date.new(year, 6, 6))

        )
        data.push(
          build(:holiday, name: "Summer Holiday",
            start_date: Date.new(year, 7, 10), end_date: Date.new(year, 9, 1))
        )
        new(data, country)
      }
    end

  end
end
