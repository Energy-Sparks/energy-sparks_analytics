require 'spec_helper'
require 'active_support/core_ext'

describe UsageBreakdown::DayTypeBreakdown, type: :service do
  let(:school)          { @acme_academy }

  before(:all) do
    @acme_academy = load_unvalidated_meter_collection(school: 'acme-academy')
  end

  context '#initialize' do
    it 'builds day type breakdowns for a given school and fuel type' do
      day_type_breakdown = UsageBreakdown::DayTypeBreakdown.new(school: school, fuel_type: :electricity)

      expect(day_type_breakdown.holidays.kwh).to round_to_two_digits(71847.1) # 71847.09999999999
      expect(day_type_breakdown.holidays.co2).to round_to_two_digits(12476.78) # 12476.783800000008
      expect(day_type_breakdown.holidays.percent).to round_to_two_digits(0.15) # 0.15371704310498283
      expect(day_type_breakdown.holidays.pounds_sterling).to round_to_two_digits(10813.95) # 10813.954999999998

      # expect(day_type_breakdown.school_day_closed.kwh).to round_to_two_digits() # 
      # expect(day_type_breakdown.school_day_closed.co2).to round_to_two_digits() # 
      # expect(day_type_breakdown.school_day_closed.percent).to round_to_two_digits() # 
      # expect(day_type_breakdown.school_day_closed.pounds_sterling).to round_to_two_digits() # 



      # expect(day_type_breakdown.holidays.as_json).to eq({"co2"=>12476.783800000008, "kwh"=>71847.09999999999, "percent"=>0.15371704310498283, "pounds_sterling"=>10813.954999999998})

      # expect(day_type_breakdown.school_day_closed.as_json).to eq({"co2"=>35745.40483333333, "kwh"=>181388.2666666666, "percent"=>0.3880806324254996, "pounds_sterling"=>27184.38200000001})
      # expect(day_type_breakdown.school_day_open.as_json).to eq({"co2"=>33246.97816666668, "kwh"=>172067.6333333333, "percent"=>0.36813911501052066, "pounds_sterling"=>26756.202000000005})
      # expect(day_type_breakdown.weekends.as_json).to eq({"co2"=>7023.472399999997, "kwh"=>42095.39999999999, "percent"=>0.09006320945899686, "pounds_sterling"=>6305.880000000001})
      # expect(day_type_breakdown.out_of_hours.as_json).to eq({"co2"=>55245.66103333332, "kwh"=>295330.7666666666, "percent"=>0.6318608849894793, "pounds_sterling"=>44304.217000000004})
      # expect(day_type_breakdown.out_of_hours_percent.round(6)).to eq((1 - day_type_breakdown.school_day_open.percent).round(6))
      # expect(day_type_breakdown.average_out_of_hours_percent).to eq(BenchmarkMetrics::AVERAGE_OUT_OF_HOURS_PERCENT)
      # expect(day_type_breakdown.total_annual_pounds_sterling).to eq(71060.41900000001)
      # expect(day_type_breakdown.total_annual_kwh).to eq(467398.3999999999)
      # expect(day_type_breakdown.total_annual_co2).to eq(88492.6392)
    end
  end
end
