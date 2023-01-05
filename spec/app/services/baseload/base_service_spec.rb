require 'spec_helper'

describe Baseload::BaseService, type: :service do

  context '#validate_meter' do
    context 'with gas meter' do
      let(:meter) { build(:meter, type: :gas) }
      it 'rejects the meter' do
        expect {
          Baseload::BaseService.new.validate_meter(meter)
        }.to raise_error EnergySparksUnexpectedStateException
      end
    end
    context 'with electricity meter' do
      let(:meter) { build(:meter, type: :electricity) }
      it 'accepts the meter' do
        Baseload::BaseService.new.validate_meter(meter)
      end
    end
  end

  context '#validate_meter_collection' do
    context 'with electricity meters' do
      let(:meter_collection) { build(:meter_collection) }
      let(:meter) { build(:meter, type: :electricity) }
      before(:each) do
        meter_collection.update_electricity_meters([meter])
      end
      it 'accepts the school' do
        Baseload::BaseService.new.validate_meter_collection(meter_collection)
      end
    end

    context 'with no electricity meters' do
      let(:meter_collection) { build(:meter_collection) }
      it 'rejects the school' do
        expect {
          Baseload::BaseService.new.validate_meter_collection(meter_collection)
        }.to raise_error EnergySparksUnexpectedStateException
      end
    end
  end

end
