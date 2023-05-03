require 'spec_helper'

describe Heating::HeatingStartTimeSavingsService, type: :service do

  let(:asof_date)      { Date.new(2022, 2, 1) }
  let(:service)        { Heating::HeatingStartTimeSavingsService.new(@acme_academy, asof_date)}

  #using before(:all) here to avoid slow loading of YAML and then
  #running the aggregation code for each test.
  before(:all) do
    @acme_academy = load_unvalidated_meter_collection(school: 'acme-academy')
  end

  context '#percentage_of_annual_gas' do
    it 'returns the expected data' do
      expect(service.percentage_of_annual_gas).to round_to_two_digits(0.04)
    end
  end

  context '#estimated_savings' do
    it 'returns the expected data' do
      estimated_savings = service.estimated_savings
      expect(estimated_savings.kwh).to round_to_two_digits(22848.69)
      expect(estimated_savings.£).to round_to_two_digits(685.46)
      expect(estimated_savings.co2).to round_to_two_digits(4798.23)
    end
  end

  context '#enough_data?' do
    context 'when theres is a years worth' do
      it 'returns true' do
        expect( service.enough_data? ).to be true
      end
    end
    context 'when theres is limited data' do
      #acme academy has gas data starting in 2018-09-01
      let(:asof_date)      { Date.new(2018, 10, 2) }
      it 'returns false' do
        expect( service.enough_data? ).to be false
      end
    end
  end
end
