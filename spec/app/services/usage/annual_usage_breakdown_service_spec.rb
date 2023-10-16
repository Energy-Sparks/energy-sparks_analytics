require 'spec_helper'

describe Usage::AnnualUsageBreakdownService, type: :service do
  Object.const_set('Rails', true) # Otherwise the test fails at line 118 (RecordTestTimes) in ChartManager

  let(:meter_collection)                     { @acme_academy }

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

  context '#annual_out_of_hours_kwh' do
    let(:usage_breakdown_benchmark_service) { Usage::AnnualUsageBreakdownService.new(meter_collection: meter_collection, fuel_type: :electricity) }
    let(:usage)                { usage_breakdown_benchmark_service.annual_out_of_hours_kwh }
    it 'returns the expected data' do
      expect(usage[:out_of_hours]).to be_within(0.01).of(260969.96)
      expect(usage[:total_annual]).to be_within(0.01).of(408845.4)
    end
  end

  context '#usage_breakdown' do
    let(:usage_breakdown_benchmark_service) { Usage::AnnualUsageBreakdownService.new(meter_collection: meter_collection, fuel_type: fuel_type) }
    let(:day_type_breakdown) { usage_breakdown_benchmark_service.usage_breakdown }

    context 'for electricity' do
      let(:fuel_type) { :electricity }

      it 'returns the holiday usage analysis' do
        expect(day_type_breakdown.holiday.kwh).to be_within(0.01).of(63961.49)
        expect(day_type_breakdown.holiday.co2).to be_within(0.01).of(9461.34)
        expect(day_type_breakdown.holiday.percent).to be_within(0.01).of(0.15)
        expect(day_type_breakdown.holiday.£).to be_within(0.01).of(9594.22)
      end

      it 'returns the school day closed usage analysis' do
        expect(day_type_breakdown.school_day_closed.kwh).to be_within(0.01).of(159532.06)
        expect(day_type_breakdown.school_day_closed.co2).to be_within(0.01).of(28572.72)
        expect(day_type_breakdown.school_day_closed.percent).to be_within(0.01).of(0.39)
        expect(day_type_breakdown.school_day_closed.£).to be_within(0.01).of(23929.80)
      end

      it 'returns the school day open usage analysis' do
        expect(day_type_breakdown.school_day_open.kwh).to be_within(0.01).of(147875.43)
        expect(day_type_breakdown.school_day_open.co2).to be_within(0.01).of(24419.41)
        expect(day_type_breakdown.school_day_open.percent).to be_within(0.01).of(0.36)
        expect(day_type_breakdown.school_day_open.£).to be_within(0.01).of(22181.31)
      end

      it 'returns the out of hours usage analysis' do
        expect(day_type_breakdown.out_of_hours.kwh).to be_within(0.01).of(260969.96)
        expect(day_type_breakdown.out_of_hours.co2).to be_within(0.01).of(43716.01)
        expect(day_type_breakdown.out_of_hours.percent).to be_within(0.01).of(0.64)
        expect(day_type_breakdown.out_of_hours.£).to be_within(0.01).of(39145.49)
      end

      it 'returns the weekend usage analysis' do
        expect(day_type_breakdown.weekend.kwh).to be_within(0.01).of(37476.39)
        expect(day_type_breakdown.weekend.co2).to be_within(0.01).of(5681.93)
        expect(day_type_breakdown.weekend.percent).to be_within(0.01).of(0.09)
        expect(day_type_breakdown.weekend.£).to be_within(0.01).of(5621.45)
      end

      it 'returns the community use analysis' do
        expect(day_type_breakdown.community.kwh).to be_within(0.01).of(0) # 0
        expect(day_type_breakdown.community.co2).to be_within(0.01).of(0) # 0
        expect(day_type_breakdown.community.percent).to be_within(0.01).of(0) # 0
        expect(day_type_breakdown.community.£).to be_within(0.01).of(0) # 0
      end

      it 'returns the totals' do
        expect(day_type_breakdown.total.kwh).to be_within(0.01).of(408845.4)
        expect(day_type_breakdown.total.co2).to be_within(0.01).of(68135.42)
      end

      it 'includes a comparison' do
        exemplar_comparison = day_type_breakdown.potential_savings(versus: :exemplar_school)

        expect(exemplar_comparison.co2).to eq(nil)
        expect(exemplar_comparison.kwh).to be_within(0.01).of(56547.26)
        expect(exemplar_comparison.percent).to be_within(0.01).of(0.14)
        expect(exemplar_comparison.£).to be_within(0.01).of(8482.09)

        comparison = day_type_breakdown.potential_savings(versus: :benchmark_school)
        expect(comparison.percent).to be_within(0.01).of(0.04)
      end
    end

    context 'for storage heater' do
      let(:fuel_type) { :storage_heater }
      let(:meter_collection) { @beta_academy }

      it 'returns the holiday usage analysis' do
        expect(day_type_breakdown.holiday.kwh).to be_within(0.01).of(16929.86)
        expect(day_type_breakdown.holiday.co2).to be_within(0.01).of(2073.21)
        expect(day_type_breakdown.holiday.percent).to be_within(0.01).of(0.15)
        expect(day_type_breakdown.holiday.£).to be_within(0.01).of(2289.13)
      end

      it 'returns the school day closed usage analysis' do
        expect(day_type_breakdown.school_day_closed.kwh).to be_within(0.01).of(79830.78)
        expect(day_type_breakdown.school_day_closed.co2).to be_within(0.01).of(12355.28)
        expect(day_type_breakdown.school_day_closed.percent).to be_within(0.01).of(0.71)
        expect(day_type_breakdown.school_day_closed.£).to be_within(0.01).of(9419.55)
      end

      it 'returns the school day open usage analysis' do
        expect(day_type_breakdown.school_day_open.kwh).to be_within(0.01).of(0.00)
        expect(day_type_breakdown.school_day_open.co2).to be_within(0.01).of(0.00)
        expect(day_type_breakdown.school_day_open.percent).to be_within(0.01).of(0.00)
        expect(day_type_breakdown.school_day_open.£).to be_within(0.01).of(0.00)
      end

      it 'returns the out of hours usage analysis' do
        expect(day_type_breakdown.out_of_hours.kwh).to be_within(0.01).of(111567.32)
        expect(day_type_breakdown.out_of_hours.co2).to be_within(0.01).of(16711.01)
        expect(day_type_breakdown.out_of_hours.percent).to be_within(0.01).of(1.0)
        expect(day_type_breakdown.out_of_hours.£).to be_within(0.01).of(13468.68)
      end

      it 'returns the weekend usage analysis' do
        expect(day_type_breakdown.weekend.kwh).to be_within(0.01).of(14806.67)
        expect(day_type_breakdown.weekend.co2).to be_within(0.01).of(2282.51)
        expect(day_type_breakdown.weekend.percent).to be_within(0.01).of(0.13)
        expect(day_type_breakdown.weekend.£).to be_within(0.01).of(1759.99)
      end

      it 'returns the community use analysis' do
        expect(day_type_breakdown.community.kwh).to round_to_two_digits(0)
        expect(day_type_breakdown.community.co2).to round_to_two_digits(0)
        expect(day_type_breakdown.community.percent).to round_to_two_digits(0)
        expect(day_type_breakdown.community.£).to round_to_two_digits(0)
      end

      it 'returns the totals' do
        expect(day_type_breakdown.total.kwh).to be_within(0.01).of(111567.32)
        expect(day_type_breakdown.total.co2).to be_within(0.01).of(16711.01)
      end

      it 'includes a comparison' do
        exemplar_comparison = day_type_breakdown.potential_savings(versus: :exemplar_school)
        expect(exemplar_comparison.co2).to eq(nil)
        expect(exemplar_comparison.kwh).to be_within(0.01).of(89253.86)
        expect(exemplar_comparison.percent).to be_within(0.01).of(0.8)
        expect(exemplar_comparison.£).to be_within(0.01).of(10774.94)
      end
    end
  end
end
