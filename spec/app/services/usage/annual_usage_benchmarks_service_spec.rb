# frozen_string_literal: true

require 'spec_helper'

describe Usage::AnnualUsageBenchmarksService, type: :service do
  let(:fuel_type) { :electricity }

  # AMR data for the school
  let(:kwh_data_x48)    { Array.new(48) { 10.0 } }
  let(:amr_start_date)  { Date.new(2021, 12, 31) }
  let(:amr_end_date)    { Date.new(2022, 12, 31) }
  let(:amr_data) { build(:amr_data, :with_date_range, :with_grid_carbon_intensity, grid_carbon_intensity: grid_carbon_intensity, start_date: amr_start_date, end_date: amr_end_date, kwh_data_x48: kwh_data_x48) }

  # Tariffs used to calculate costs
  let(:rates) { create_flat_rate(rate: 0.10, standing_charge: 1.0) }
  let(:accounting_tariff) { create_accounting_tariff_generic(start_date: amr_start_date, end_date: amr_end_date, rates: rates) }
  let(:meter_attributes) do
    { accounting_tariff_generic: [accounting_tariff] }
  end

  # Carbon intensity used to calculate co2 emissions
  let(:grid_carbon_intensity) { build(:grid_carbon_intensity, :with_days, start_date: amr_start_date, end_date: amr_end_date, kwh_data_x48: Array.new(48) { 0.2 }) }

  let(:degree_day_adjustment) { 1.0 }

  # Meter to use as the aggregate
  let(:meter) { build(:meter, type: fuel_type, meter_attributes: meter_attributes, amr_data: amr_data) }

  # primary school, with 1000 pupils and 5000 sq m2 by default
  let(:meter_collection) { build(:meter_collection) }

  let(:asof_date)        { Date.new(2022, 12, 31) }

  let(:service)          { Usage::AnnualUsageBenchmarksService.new(meter_collection, fuel_type, asof_date) }

  before do
    allow(meter_collection).to receive(:aggregate_meter).and_return(meter)
    allow(BenchmarkMetrics).to receive(:normalise_degree_days).and_return(degree_day_adjustment)
    # TODO: this could be moved to factory
    meter.set_tariffs
  end

  describe '#enough_data?' do
    context 'with electricity' do
      context 'with enough data' do
        it 'returns true' do
          expect(service.enough_data?).to be true
        end
      end

      context 'with limited data' do
        let(:amr_start_date) { Date.new(2022, 12, 1) }

        it 'returns false' do
          expect(service.enough_data?).to be false
        end
      end
    end

    context 'with gas' do
      let(:fuel_type) { :gas }

      context 'when there is enough data' do
        context 'with limited data' do
          let(:amr_start_date) { Date.new(2022, 12, 1) }

          it 'returns false' do
            expect(service.enough_data?).to be false
          end
        end

        it 'returns true' do
          expect(service.enough_data?).to be true
        end
      end
    end
  end

  describe '#annual_usage' do
    context 'with electricity' do
      it 'calculates the expected values for a benchmark school' do
        annual_usage = service.annual_usage(compare: :benchmark_school)
        expect(annual_usage.kwh).to be_within(0.01).of(220_000.0)
        expect(annual_usage.co2).to be_within(0.01).of(44_000.0) # 0.2 * kwh
        expect(annual_usage.£).to be_within(0.01).of(22_000.0) # 0.1 * kwh
      end

      it 'calculates the expected values for an exemplar school' do
        annual_usage = service.annual_usage(compare: :exemplar_school)
        expect(annual_usage.kwh).to be_within(0.01).of(190_000.0)
        expect(annual_usage.co2).to be_within(0.01).of(38_000.0) # 0.2 * kwh
        expect(annual_usage.£).to be_within(0.01).of(19_000.0) # 0.1 * kwh
      end
    end

    context 'with gas' do
      let(:fuel_type)     { :gas }
      let(:kwh_data_x48)  { Array.new(48) { 5.0 } }

      it 'calculates the expected values for a benchmark school' do
        annual_usage = service.annual_usage(compare: :benchmark_school)
        expect(annual_usage.kwh).to be_within(0.01).of(431_250.0)
        expect(annual_usage.co2).to be_within(0.01).of(86_250.0) # 0.2 * kwh
        expect(annual_usage.£).to be_within(0.01).of(43_125.0) # 0.1 * kwh
      end

      it 'calculates the expected values for an exemplar school' do
        annual_usage = service.annual_usage(compare: :exemplar_school)
        expect(annual_usage.kwh).to be_within(0.01).of(400_000.0)
        expect(annual_usage.co2).to be_within(0.01).of(80_000.0) # 0.2 * kwh
        expect(annual_usage.£).to be_within(0.01).of(40_000.0) # 0.1 * kwh
      end
    end
  end

  describe '#estimate_savings' do
    context 'with electricity' do
      it 'calculates the expected values for a benchmark school' do
        savings = service.estimated_savings(versus: :benchmark_school)
        expect(savings.kwh).to be_within(0.01).of(45_280.0)
        expect(savings.£).to be_within(0.01).of(4528.0)
        expect(savings.co2).to be_within(0.01).of(9056.0)
        expect(savings.percent).to be_within(0.01).of(-0.20)
      end

      it 'calculates the expected values for an exemplar school' do
        savings = service.estimated_savings(versus: :exemplar_school)
        expect(savings.kwh).to be_within(0.01).of(15_280.0)
        expect(savings.£).to be_within(0.01).of(1528.0)
        expect(savings.co2).to be_within(0.01).of(3056.0)
        expect(savings.percent).to be_within(0.01).of(-0.08)
      end
    end

    context 'with gas' do
      let(:fuel_type) { :gas }

      it 'calculates the expected values for a benchmark school' do
        savings = service.estimated_savings(versus: :benchmark_school)
        expect(savings.kwh).to be_within(0.01).of(256_530.0)
        expect(savings.£).to be_within(0.01).of(25_653.0)
        expect(savings.co2).to be_within(0.01).of(51_306.0)
        expect(savings.percent).to be_within(0.01).of(-0.59)
      end

      it 'calculates the expected values for an exemplar school' do
        savings = service.estimated_savings(versus: :exemplar_school)
        expect(savings.kwh).to be_within(0.01).of(225_280.0)
        expect(savings.£).to be_within(0.01).of(22_528.0)
        expect(savings.co2).to be_within(0.01).of(45_056.0)
        expect(savings.percent).to be_within(0.01).of(-0.56)
      end
    end
  end
end
