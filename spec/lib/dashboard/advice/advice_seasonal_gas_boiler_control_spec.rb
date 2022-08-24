require 'spec_helper'

describe AdviceGasBoilerSeasonalControl do

  context '#warm_weather_on_days_adjective' do
    it 'returns expected ratings' do
      expect(described_class.warm_weather_on_days_adjective(1)).to eq 'excellent'
      expect(described_class.warm_weather_on_days_adjective(7)).to eq 'good'
      expect(described_class.warm_weather_on_days_adjective(14)).to eq 'above average'
      expect(described_class.warm_weather_on_days_adjective(20)).to eq 'poor'
      expect(described_class.warm_weather_on_days_adjective(100)).to eq 'very poor'
    end
  end
end
