require 'spec_helper'

describe Dashboard::Meter do

  context '#create' do

    let(:type) { :electricity }
    let(:identifier) { 1234567890 }

    let(:valid_params) {
      {
        meter_collection: [],
        amr_data: nil,
        type: type,
        identifier: identifier,
        name: 'some-meter-name',
        floor_area: nil,
        number_of_pupils: nil,
        solar_pv_installation: nil,
        storage_heater_config: nil,
        external_meter_id: nil,
        dcc_meter: true,
        meter_attributes: {}
      }
    }

    describe "#initialize" do
      it "creates a meter" do
        meter = Dashboard::Meter.new(**valid_params)
        expect(meter.mpan_mprn).to eq(identifier)
        expect(meter.dcc_meter).to be true
      end

      it "creates a heat meter" do
        [:gas, :storage_heater, :aggregated_heat].each do |type|
          meter = Dashboard::Meter.new(**valid_params.merge({type: type}))
          expect(meter.heat_meter?).to be true
          expect(meter.electricity_meter?).to be false
        end
      end

      it "creates an electricity meter" do
        [:electricity, :solar_pv, :aggregated_electricity].each do |type|
          meter = Dashboard::Meter.new(**valid_params.merge({type: type}))
          expect(meter.heat_meter?).to be false
          expect(meter.electricity_meter?).to be true
        end
      end
    end

    describe '#inspect' do
      let(:meter) { Dashboard::Meter.new(**valid_params.merge({type: type})) }
      it 'works as expected' do
        expect(meter.inspect).to include(identifier.to_s)
        expect(meter.inspect).to include(type.to_s)
      end
    end

    describe '#analytics_name' do
      let(:identifier)  { "1456789" }
      let(:name)        { nil }

      let(:meter) { build(:meter, identifier: identifier, name: name) }

      it 'returns mpxn by default' do
        expect(meter.analytics_name).to eq(identifier)
      end

      context 'with name' do
        let(:name)  { "Kitchen" }

        it 'returns bracketed text' do
          expect(meter.analytics_name).to eq("Kitchen (1456789)")
        end
      end
    end

    # TODO check on fuel type not currently applied
    # it "raises error for unknown fuel type" do
    #   expect {
    #     Dashboard::Meter.new(valid_params.merge({type: :fruit}))
    #   }.to raise_error(EnergySparksUnexpectedStateException.new("Unexpected fuel type fruit"))
    # end
  end
end
