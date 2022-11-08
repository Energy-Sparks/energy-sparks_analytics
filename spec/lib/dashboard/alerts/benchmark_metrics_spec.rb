require 'spec_helper'

describe BenchmarkMetrics do
  describe '#pricing' do
    it 'returns the default pricing values' do
      expect(BenchmarkMetrics.pricing.class).to eq(OpenStruct)
      expect(BenchmarkMetrics.pricing.to_h).to eq(
      	{
      	  gas_price: BenchmarkMetrics::DEFAULT_GAS_PRICE,
      	  oil_price: BenchmarkMetrics::DEFAULT_OIL_PRICE,
      	  electricity_price: BenchmarkMetrics::DEFAULT_ELECTRICITY_PRICE,
      	  solar_export_price: BenchmarkMetrics::DEFAULT_SOLAR_EXPORT_PRICE
      	}
      )      
    end

    it 'returns the pricing values as defined in the ES rails application database' do
      stub_const('Rails', true)
      stub_const(
        "EnergySparks::FeatureFlags",
        Class.new do
          def self.active?(feature)
            true
          end
        end
      )
      stub_const(
        "SiteSettings",
        Class.new do
          def self.current_prices
          end
        end
      )

      allow(SiteSettings).to receive(:current_prices).and_return(
      	OpenStruct.new(
      	  gas_price: 0.09,
      	  oil_price: 0.08,
      	  electricity_price: 0.17,
      	  solar_export_price: 0.075
      	)
      )

      expect(BenchmarkMetrics.pricing.class).to eq(OpenStruct)
      expect(BenchmarkMetrics.pricing.to_h).to eq(
      	{
      	  gas_price: 0.09,
      	  oil_price: 0.08,
      	  electricity_price: 0.17,
      	  solar_export_price: 0.075
      	}
      )
    end
  end
end
