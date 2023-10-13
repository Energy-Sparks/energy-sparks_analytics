require 'spec_helper'

describe MeterCollection do

  describe '#inspect' do
    let(:meter_collection) { build(:meter_collection) }
    it 'works as expected' do
      expect(meter_collection.inspect).to include("Meter Collection")
      expect(meter_collection.inspect).to include(meter_collection.school.name)
    end
  end

  describe '#notify_aggregation_complete!' do
    let(:meter_collection)    { build(:meter_collection, :with_electricity_and_gas_meters) }

    it 'notifies all data associated with all the meters' do
      meter_collection.all_meters.each do |m|
        expect(m.amr_data).to receive(:set_post_aggregation_state)
      end
      meter_collection.notify_aggregation_complete!
    end

    context 'when there is schedule data to clean up' do
      let(:first_combined_meter_date)     { Date.today - 3 }
      before do
        allow(meter_collection).to receive(:first_combined_meter_date).and_return(first_combined_meter_date)
        meter_collection.notify_aggregation_complete!
      end

      it 'cleans up the data as expected' do
        expect(meter_collection.solar_irradiation.start_date).to eq first_combined_meter_date
        expect(meter_collection.solar_pv.start_date).to eq first_combined_meter_date

        #for some reason this class overrides start/end date to throw an exception
        #so check for changes another way...
        expect(meter_collection.grid_carbon_intensity.key?(first_combined_meter_date)).to eq true
        expect(meter_collection.grid_carbon_intensity.key?(first_combined_meter_date - 1)).to eq false
      end

      it 'has a special case for temperatures' do
        expect(meter_collection.temperatures.start_date).to eq (first_combined_meter_date - 369)
      end
    end

  end

end
