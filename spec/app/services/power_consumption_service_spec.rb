require 'spec_helper'

describe PowerConsumptionService do

  let(:school)                  { build(:school) }
  let(:meter_collection)        { build(:meter_collection) }
  let(:meter)                   { build(:meter, type: :electricity) }

  let(:service)                 { PowerConsumptionService.create_service(meter_collection, meter) }

  context '#create_service' do
    it 'creates without error' do
      expect(service).to_not be_nil
    end
  end

  context '#perform' do
    it 'returns a reading' do
      expect(service.perform).to be_a(Float)
    end
  end
end
