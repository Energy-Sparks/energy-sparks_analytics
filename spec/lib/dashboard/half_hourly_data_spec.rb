require 'spec_helper'

describe HalfHourlyData do

  describe '#inspect' do
    let(:data) { HalfHourlyData.new(:electricity) }

    it 'works as expected' do
     expect(data.inspect).to include("HalfHourlyData")
     expect(data.inspect).to include("days: 0")
    end
  end

end
