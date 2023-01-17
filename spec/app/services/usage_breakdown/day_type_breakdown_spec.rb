require 'spec_helper'
require 'active_support/core_ext'

describe UsageBreakdown::DayTypeBreakdown, type: :service do
  let(:school)          { @acme_academy }

  before(:all) do
    @acme_academy = load_unvalidated_meter_collection(school: 'acme-academy')
    Object.const_set('Rails', true) # Otherwise the test fails at line 118 (RecordTestTimes) in ChartManager
  end

  context '#initialize' do
    it 'builds day type breakdowns for a given school and fuel type' do
      day_type_breakdown = UsageBreakdown::DayTypeBreakdown.new(school: school, fuel_type: :electricity)

      expect(day_type_breakdown.holidays.kwh).to round_to_two_digits(71847.1) # 71847.09999999999
      expect(day_type_breakdown.holidays.co2).to round_to_two_digits(12476.78) # 12476.783800000008
      expect(day_type_breakdown.holidays.percent).to round_to_two_digits(0.15) # 0.15371704310498283
      expect(day_type_breakdown.holidays.pounds_sterling).to round_to_two_digits(10813.95) # 10813.954999999998

      expect(day_type_breakdown.school_day_closed.kwh).to round_to_two_digits(181388.27) # 
      expect(day_type_breakdown.school_day_closed.co2).to round_to_two_digits(35745.40) # 
      expect(day_type_breakdown.school_day_closed.percent).to round_to_two_digits(0.39) # 
      expect(day_type_breakdown.school_day_closed.pounds_sterling).to round_to_two_digits(27184.38) # 

      expect(day_type_breakdown.school_day_open.kwh).to round_to_two_digits(172067.63) # 172067.6333333333
      expect(day_type_breakdown.school_day_open.co2).to round_to_two_digits(33246.98) # 33246.97816666668
      expect(day_type_breakdown.school_day_open.percent).to round_to_two_digits(0.37) # 0.36813911501052066 
      expect(day_type_breakdown.school_day_open.pounds_sterling).to round_to_two_digits(26756.20) # 26756.202000000005

      expect(day_type_breakdown.out_of_hours.kwh).to round_to_two_digits(295330.77) # 295330.7666666666 
      expect(day_type_breakdown.out_of_hours.co2).to round_to_two_digits(55245.66) # 55245.66103333332
      expect(day_type_breakdown.out_of_hours.percent).to round_to_two_digits(0.63) # 0.6318608849894793
      expect(day_type_breakdown.out_of_hours.pounds_sterling).to round_to_two_digits(44304.22) # 44304.217000000004

      expect(day_type_breakdown.weekends.kwh).to round_to_two_digits(42095.40) # 42095.39999999999
      expect(day_type_breakdown.weekends.co2).to round_to_two_digits(7023.47) # 7023.472399999997
      expect(day_type_breakdown.weekends.percent).to round_to_two_digits(0.09) # 0.09006320945899686
      expect(day_type_breakdown.weekends.pounds_sterling).to round_to_two_digits(6305.88) # 6305.880000000001

      expect(day_type_breakdown.community.kwh).to round_to_two_digits(0) # 0
      expect(day_type_breakdown.community.co2).to round_to_two_digits(0) # 0
      expect(day_type_breakdown.community.percent).to round_to_two_digits(0) # 0
      expect(day_type_breakdown.community.pounds_sterling).to round_to_two_digits(0) # 0

      expect(day_type_breakdown.out_of_hours_percent).to round_to_two_digits(0.63) # 0.6318608849894793
      expect(day_type_breakdown.average_out_of_hours_percent).to round_to_two_digits(BenchmarkMetrics::AVERAGE_OUT_OF_HOURS_PERCENT) # 0.5
      expect(day_type_breakdown.total_annual_pounds_sterling).to round_to_two_digits(71060.42) # 71060.41900000001
      expect(day_type_breakdown.total_annual_kwh).to round_to_two_digits(467398.40) # 467398.3999999999
      expect(day_type_breakdown.total_annual_co2).to round_to_two_digits(88492.64) # 88492.6392
    end
  end
end
