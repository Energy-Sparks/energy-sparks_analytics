require 'spec_helper'

describe EnergyEquivalences do
  Object.const_set('Rails', true) # Otherwise the test fails at line 118 (RecordTestTimes) in ChartManager

  describe '#create_configuration' do
    it 'creates a configuration' do
      # TODO
    end
  end

  it 'checks constants reflect benchmark metrics pricing' do
    expect(EnergyEquivalences::UK_ELECTRIC_GRID_£_KWH).to eq(0.15)
    expect(EnergyEquivalences::UK_GAS_£_KWH).to eq(0.03)
    new_pricing = OpenStruct.new(gas_price: 0.06, oil_price: 0.1, electricity_price: 0.3, solar_export_price: 0.1)
    class_double('BenchmarkMetrics', pricing: new_pricing, default_prices: new_pricing).as_stubbed_const
    expect(EnergyEquivalences::UK_ELECTRIC_GRID_£_KWH).to eq(0.3)
    expect(EnergyEquivalences::UK_GAS_£_KWH).to eq(0.06)
  end
end
