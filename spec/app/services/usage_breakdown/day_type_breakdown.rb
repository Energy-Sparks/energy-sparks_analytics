require 'spec_helper'

describe UsageBreakdown::DayTypeBreakdown, type: :service do
  let(:school)          { @acme_academy }

  before(:all) do
    @acme_academy = load_unvalidated_meter_collection(school: 'acme-academy')
  end

  context '#out_of_hours_percent' do
    it 'calculates the total percentage of out of hours usage' do
      day_type_breakdown = UsageBreakdown::DayTypeBreakdown.new(school: school)
      expect(day_type_breakdown.out_of_hours_percent).to eq(0)
    end
  end

  context '#calculate_kwh' do
    it 'summarises kwh for all day types' do
      day_type_breakdown = UsageBreakdown::DayTypeBreakdown.new(school: school)
      day_type_breakdown.calculate_kwh!
      expect(day_type_breakdown.holidays.kwh).to eq(71847.09999999999)
      expect(day_type_breakdown.weekends.kwh).to eq(42095.39999999999)
      expect(day_type_breakdown.school_day_open.kwh).to eq(172067.6333333333)
      expect(day_type_breakdown.school_day_closed.kwh).to eq(181388.2666666666)
      expect(day_type_breakdown.out_of_hours.kwh).to eq(295330.7666666666)

      expect(day_type_breakdown.holidays.percent).to eq(0.15371704310498283)
      expect(day_type_breakdown.weekends.percent).to eq(0.09006320945899686)
      expect(day_type_breakdown.school_day_open.percent).to eq(0.36813911501052066)
      expect(day_type_breakdown.school_day_closed.percent).to eq(0.3880806324254996)
      expect(day_type_breakdown.out_of_hours.percent).to eq(0.6318608849894793)



    end
  end
end
