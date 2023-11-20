# frozen_string_literal: true

require 'spec_helper'
require 'dashboard'

describe BenchmarkMetrics do
  describe '.benchmark_annual_electricity_usage_kwh' do
    let(:pupils) { 10 }
    let(:annual_usage_kwh) do
      BenchmarkMetrics.benchmark_annual_electricity_usage_kwh(school_type, pupils)
    end

    context 'with a primary school' do
      let(:school_type) { :primary }

      it 'returns the expected value' do
        expect(annual_usage_kwh).to eq 2200
      end
    end

    context 'with a secondary school' do
      let(:school_type) { :secondary }

      it 'returns the expected value' do
        expect(annual_usage_kwh).to eq 3828
      end
    end

    context 'with a special school' do
      let(:school_type) { :special }

      it 'returns the expected value' do
        expect(annual_usage_kwh).to eq 8950
      end
    end

    context 'with an unknown school type' do
      let(:school_type) { :unknown }

      it 'throws an exception' do
        expect { annual_usage_kwh }.to raise_error(EnergySparksUnexpectedStateException)
      end
    end
  end

  describe '.exemplar_annual_electricity_usage_kwh' do
    let(:pupils) { 10 }
    let(:annual_usage_kwh) do
      BenchmarkMetrics.exemplar_annual_electricity_usage_kwh(school_type, pupils)
    end

    context 'with a primary school' do
      let(:school_type) { :primary }

      it 'returns the expected value' do
        expect(annual_usage_kwh).to eq 1900
      end
    end

    context 'with a secondary school' do
      let(:school_type) { :secondary }

      it 'returns the expected value' do
        expect(annual_usage_kwh).to eq 3306
      end
    end

    context 'with a special school' do
      let(:school_type) { :special }

      it 'returns the expected value' do
        expect(annual_usage_kwh).to eq 2750
      end
    end

    context 'with an unknown school type' do
      let(:school_type) { :unknown }

      it 'throws an exception' do
        expect { annual_usage_kwh }.to raise_error(EnergySparksUnexpectedStateException)
      end
    end
  end
end
