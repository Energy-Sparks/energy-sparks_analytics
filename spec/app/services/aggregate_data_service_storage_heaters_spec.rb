# frozen_string_literal: true

require 'spec_helper'

describe AggregateDataServiceStorageHeaters do
  subject(:service) { described_class.new(meter_collection) }

  let(:meter_collection) do
    build(:meter_collection)
  end

  let!(:electricity_meter) do
    kwh_data_x48 = Array.new(48, 1.0)
    meter_attributes = {}
    meter_attributes[:storage_heaters] = [{ charge_start_time: TimeOfDay.parse('02:00'),
                                            charge_end_time: TimeOfDay.parse('06:00') }]

    # match charge times, increases usage just enough for model to consider heating on
    kwh_data_x48[4, 10] = [4.0] * 10
    meter = build(:meter,
                  meter_collection: meter_collection,
                  type: :electricity, meter_attributes: meter_attributes,
                  amr_data: build(:amr_data, :with_date_range, type: :electricity,
                                                               start_date: Date.new(2023, 1, 1),
                                                               end_date: Date.new(2023, 12, 31),
                                                               kwh_data_x48: kwh_data_x48))
    meter_collection.add_electricity_meter(meter)
    meter
  end

  shared_examples 'a successfully aggregated storage heater setup' do
    it 'sets the aggregate meters' do
      expect(meter_collection.aggregated_electricity_meters).not_to be_nil
      expect(meter_collection.storage_heater_meter).not_to be_nil
    end

    it 'configures the aggregate sub_meters' do
      expect(meter_collection.aggregated_electricity_meters.sub_meters[:mains_consume]).not_to be_nil
      expect(meter_collection.aggregated_electricity_meters.sub_meters[:storage_heaters]).not_to be_nil
    end
  end

  describe '#disaggregate' do
    context 'with single electricity meter' do
      before do
        service.disaggregate
      end

      context 'with single storage heater' do
        it_behaves_like 'a successfully aggregated storage heater setup'

        it 'replaces the original meter with a new synthetic meter, linking the two together' do
          expect(meter_collection.electricity_meters.first).not_to eq(electricity_meter)
          expect(meter_collection.electricity_meters.first.synthetic_mpan_mprn?).to be true
          expect(meter_collection.electricity_meters.first.sub_meters[:mains_consume]).to eq(electricity_meter)
        end

        it 'recalculates the amr data' do
          total_storage = meter_collection.storage_heater_meter.amr_data.total
          expect(total_storage).not_to eq(0.0)
          total_aggregate = meter_collection.aggregated_electricity_meters.amr_data.total
          expect(total_aggregate + total_storage).to eq(electricity_meter.amr_data.total)
        end
      end

      context 'with solar panels' do
        it 'retains submeters'
      end
    end

    context 'with multiple electricity meters' do
      let(:meter_attributes) { {} }
      let!(:second_meter) do
        kwh_data_x48 = Array.new(48, 1.0)
        # match charge times, increases usage just enough for model to consider heating on
        kwh_data_x48[4, 10] = [4.0] * 10
        meter = build(:meter,
                      meter_collection: meter_collection,
                      type: :electricity, meter_attributes: meter_attributes,
                      amr_data: build(:amr_data, :with_date_range, type: :electricity,
                                                                   start_date: Date.new(2023, 1, 1),
                                                                   end_date: Date.new(2023, 12, 31),
                                                                   kwh_data_x48: kwh_data_x48))
        meter_collection.add_electricity_meter(meter)
        meter
      end

      before do
        service.disaggregate
      end

      context 'when there is a single storage heater' do
        it_behaves_like 'a successfully aggregated storage heater setup'

        it 'adds up the mains consumption'

        it 'recalculates the amr data' do
          total_storage = meter_collection.storage_heater_meter.amr_data.total
          expect(total_storage).not_to eq(0.0)
          total_aggregate = meter_collection.aggregated_electricity_meters.amr_data.total
          expect(total_aggregate + total_storage).to eq(electricity_meter.amr_data.total + second_meter.amr_data.total)
        end
      end

      context 'when there are storage heaters on different meters' do
        let(:meter_attributes) do
          meter_attributes = {}
          meter_attributes[:storage_heaters] = [{ charge_start_time: TimeOfDay.parse('02:00'),
                                                  charge_end_time: TimeOfDay.parse('06:00') }]
          meter_attributes
        end

        it_behaves_like 'a successfully aggregated storage heater setup'

        it 'recalculates the amr data' do
          total_storage = meter_collection.storage_heater_meter.amr_data.total
          expect(total_storage).not_to eq(0.0)
          total_aggregate = meter_collection.aggregated_electricity_meters.amr_data.total
          expect(total_aggregate + total_storage).to eq(electricity_meter.amr_data.total + second_meter.amr_data.total)
        end
      end

      context 'with solar panels' do
        it 'retains submeters'
      end
    end
  end
end
