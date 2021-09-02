require 'spec_helper'

describe AggregateDataService do

  context '#validate_meter_data' do

    context "when validation fails" do
      let(:school)                  { build(:school) }
      let(:meter_collection)        { build(:meter_collection) }
      let(:service)                 { AggregateDataService.new(meter_collection) }
      let(:meter)                   { build(:meter) }

      #https://github.com/rollbar/rollbar-gem/blob/63c68eed6a8066cdd8e09ab5429728d187482b12/lib/rollbar/plugins/error_context.rb
      class FakeRollbarError < StandardError
        attr_accessor :rollbar_context
      end

     # it "should validate empty readings" do
     #   meter_collection.add_heat_meter(meter)
     #   service.validate_meter_data.inspect
     # end

      it "should bubble up exception" do
        allow_any_instance_of(ValidateAMRData).to receive(:validate).and_raise("boom")
        meter_collection.add_heat_meter(meter)
        expect{ service.validate_meter_data }.to raise_error(RuntimeError)
      end

      it "should add context to Exception when Rollbar context is available" do
        error = FakeRollbarError.new
        meter_collection.add_heat_meter(meter)
        allow_any_instance_of(ValidateAMRData).to receive(:validate).and_raise(error)
        expect{ service.validate_meter_data }.to raise_error(FakeRollbarError)
        expect( error.rollbar_context ).to eql({
            mpan_mprn: meter.id
          })
      end

    end
  end
end
