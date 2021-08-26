require 'spec_helper'

describe MeterCollection do

  describe '#inspect' do
    let(:meter_collection) { build(:meter_collection) }
    it 'works as expected' do
      expect(meter_collection.inspect).to include("Meter Collection")
      expect(meter_collection.inspect).to include(meter_collection.school.name)
    end
  end
end
