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
end
