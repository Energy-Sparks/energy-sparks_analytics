require 'spec_helper'

describe Usage::AnnualUsageBreakdownService, type: :service do
  Object.const_set('Rails', true) # Otherwise the test fails at line 118 (RecordTestTimes) in ChartManager

  let(:meter_collection)                     { @acme_academy }
  let(:meter_collection_with_storage_heater) { @beta_academy }

  before(:all) do
    @acme_academy = load_unvalidated_meter_collection(school: 'acme-academy')
    @beta_academy = load_unvalidated_meter_collection(school: 'beta-academy')
  end

  context '#enough_data?' do
    it 'returns true if one years worth of data is available' do
      usage_breakdown_benchmark_service = Usage::AnnualUsageBreakdownService.new(meter_collection: meter_collection, fuel_type: :electricity)
      expect(usage_breakdown_benchmark_service.enough_data?).to eq(true)
    end
  end

  context '#data_available_from' do
    it 'returns true if one years worth of data is available' do
      usage_breakdown_benchmark_service = Usage::AnnualUsageBreakdownService.new(meter_collection: meter_collection, fuel_type: :electricity)
      expect(usage_breakdown_benchmark_service.data_available_from).to eq(nil)
    end
  end

  context '#usage_breakdown' do
    it 'returns a usage category breakdown with calculated combined usage metrics for holiday, school open days etc for electricity' do
      usage_breakdown_benchmark_service = Usage::AnnualUsageBreakdownService.new(meter_collection: meter_collection, fuel_type: :electricity)
      day_type_breakdown = usage_breakdown_benchmark_service.usage_breakdown

      expect(day_type_breakdown.holiday.kwh).to round_to_two_digits(71847.1) # 71847.09999999999
      expect(day_type_breakdown.holiday.co2).to round_to_two_digits(12476.78) # 12476.783800000008
      expect(day_type_breakdown.holiday.percent).to round_to_two_digits(0.15) # 0.15371704310498283
      expect(day_type_breakdown.holiday.£).to round_to_two_digits(10813.95) # 10813.954999999998

      expect(day_type_breakdown.school_day_closed.kwh).to round_to_two_digits(186221.67)
      expect(day_type_breakdown.school_day_closed.co2).to round_to_two_digits(36732.62)
      expect(day_type_breakdown.school_day_closed.percent).to round_to_two_digits(0.4)
      expect(day_type_breakdown.school_day_closed.£).to round_to_two_digits(27935.39)

      expect(day_type_breakdown.school_day_open.kwh).to round_to_two_digits(167234.23)
      expect(day_type_breakdown.school_day_open.co2).to round_to_two_digits(32259.76)
      expect(day_type_breakdown.school_day_open.percent).to round_to_two_digits(0.36)
      expect(day_type_breakdown.school_day_open.£).to round_to_two_digits(26005.19)

      expect(day_type_breakdown.out_of_hours.kwh).to round_to_two_digits(300164.17)
      expect(day_type_breakdown.out_of_hours.co2).to round_to_two_digits(56232.88)
      expect(day_type_breakdown.out_of_hours.percent).to round_to_two_digits(0.64)
      expect(day_type_breakdown.out_of_hours.£).to round_to_two_digits(45055.23)

      expect(day_type_breakdown.weekend.kwh).to round_to_two_digits(42095.40) # 42095.39999999999
      expect(day_type_breakdown.weekend.co2).to round_to_two_digits(7023.47) # 7023.472399999997
      expect(day_type_breakdown.weekend.percent).to round_to_two_digits(0.09) # 0.09006320945899686
      expect(day_type_breakdown.weekend.£).to round_to_two_digits(6305.88) # 6305.880000000001

      expect(day_type_breakdown.community.kwh).to round_to_two_digits(0) # 0
      expect(day_type_breakdown.community.co2).to round_to_two_digits(0) # 0
      expect(day_type_breakdown.community.percent).to round_to_two_digits(0) # 0
      expect(day_type_breakdown.community.£).to round_to_two_digits(0) # 0

      expect(day_type_breakdown.total.kwh).to round_to_two_digits(467_398.40) # 467398.3999999999
      expect(day_type_breakdown.total.co2).to round_to_two_digits(88_492.64) # 88492.6392

      exemplar_comparison = day_type_breakdown.potential_savings(versus: :exemplar_school)
      expect(exemplar_comparison.co2).to eq(nil)
      expect(exemplar_comparison.kwh).to round_to_two_digits(66464.97)
      expect(exemplar_comparison.percent).to round_to_two_digits(0.14)
      expect(exemplar_comparison.£).to round_to_two_digits(10104.93)

      comparison = day_type_breakdown.potential_savings(versus: :benchmark_school)
      expect(comparison.percent).to round_to_two_digits(0.04)
    end

    it 'returns a usage category breakdown with calculated combined usage metrics for holiday, school open days etc for storage heater' do
      usage_breakdown_benchmark_service = Usage::AnnualUsageBreakdownService.new(meter_collection: meter_collection_with_storage_heater, fuel_type: :storage_heater)
      day_type_breakdown = usage_breakdown_benchmark_service.usage_breakdown

      expect(day_type_breakdown.holiday.kwh).to round_to_two_digits(21359.91) # 21359.912500000002
      expect(day_type_breakdown.holiday.co2).to round_to_two_digits(2940.11) # 12476.78
      expect(day_type_breakdown.holiday.percent).to round_to_two_digits(0.16) # 0.15371704310498283
      expect(day_type_breakdown.holiday.£).to round_to_two_digits(3203.99) # 3203.986874999999

      expect(day_type_breakdown.school_day_closed.kwh).to round_to_two_digits(88657.96) # 88657.96250000004
      expect(day_type_breakdown.school_day_closed.co2).to round_to_two_digits(14412.63) # 14412.626000000004
      expect(day_type_breakdown.school_day_closed.percent).to round_to_two_digits(0.66) # 0.6604774659312422
      expect(day_type_breakdown.school_day_closed.£).to round_to_two_digits(13298.69) # 13298.694374999997

      expect(day_type_breakdown.school_day_open.kwh).to round_to_two_digits(0.00) # 0.00
      expect(day_type_breakdown.school_day_open.co2).to round_to_two_digits(0.00) # 0.00
      expect(day_type_breakdown.school_day_open.percent).to round_to_two_digits(0.00) # 0.00
      expect(day_type_breakdown.school_day_open.£).to round_to_two_digits(0.00) # 0.00

      expect(day_type_breakdown.out_of_hours.kwh).to round_to_two_digits(134233.14) # 134233.13750000004
      expect(day_type_breakdown.out_of_hours.co2).to round_to_two_digits(20762.91) # 20762.907862500004
      expect(day_type_breakdown.out_of_hours.percent).to round_to_two_digits(1.0) # 1.0
      expect(day_type_breakdown.out_of_hours.£).to round_to_two_digits(20134.97) # 20134.970624999994

      expect(day_type_breakdown.weekend.kwh).to round_to_two_digits(24215.26) # 24215.2625
      expect(day_type_breakdown.weekend.co2).to round_to_two_digits(3410.18) # 3410.1756624999994
      expect(day_type_breakdown.weekend.percent).to round_to_two_digits(0.18) # 0.18039705359639674
      expect(day_type_breakdown.weekend.£).to round_to_two_digits(3632.29) # 3632.289374999999

      expect(day_type_breakdown.community.kwh).to round_to_two_digits(0) # 0
      expect(day_type_breakdown.community.co2).to round_to_two_digits(0) # 0
      expect(day_type_breakdown.community.percent).to round_to_two_digits(0) # 0
      expect(day_type_breakdown.community.£).to round_to_two_digits(0) # 0

      expect(day_type_breakdown.total.kwh).to round_to_two_digits(134233.14) # 134233.13750000004
      expect(day_type_breakdown.total.co2).to round_to_two_digits(20762.91) # 20762.907862500004

      exemplar_comparison = day_type_breakdown.potential_savings(versus: :exemplar_school)
      expect(exemplar_comparison.co2).to eq(nil)
      expect(exemplar_comparison.kwh).to round_to_two_digits(107386.51) # 107386.51000000004
      expect(exemplar_comparison.percent).to round_to_two_digits(0.8) # 0.8
      expect(exemplar_comparison.£).to round_to_two_digits(16107.98) # 16107.976499999997
    end
  end
end
