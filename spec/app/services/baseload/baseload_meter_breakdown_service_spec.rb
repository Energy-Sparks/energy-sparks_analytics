# frozen_string_literal: true

require 'spec_helper'

describe Baseload::BaseloadCalculationService, type: :service do
  let(:asof_date)      { Date.new(2022, 2, 1) }
  let(:service)        { Baseload::BaseloadMeterBreakdownService.new(@acme_academy) }

  let(:meter_1)        { 1_591_058_886_735 }
  let(:meter_2)        { 1_580_001_320_420 }

  # using before(:all) here to avoid slow loading of YAML and then
  # running the aggregation code for each test.
  before(:all) do
    @acme_academy = load_unvalidated_meter_collection(school: 'acme-academy')
  end

  describe '#calculate_breakdown' do
    it 'runs the calculation' do
      meter_breakdown = service.calculate_breakdown
      expect(meter_breakdown.meters).to match_array([meter_1, meter_2])
      expect(meter_breakdown.baseload_kw(meter_1)).not_to be_nil
      expect(meter_breakdown.percentage_baseload(meter_1)).not_to be_nil
      expect(meter_breakdown.baseload_cost_£(meter_1)).not_to be_nil

      kw_1 = meter_breakdown.baseload_kw(meter_1)
      kw_2 = meter_breakdown.baseload_kw(meter_2)
      expect(meter_breakdown.total_baseload_kw).to eq(kw_1 + kw_2)

      perc_1 = meter_breakdown.percentage_baseload(meter_1)
      perc_2 = meter_breakdown.percentage_baseload(meter_2)
      expect(perc_1 + perc_2).to eq(1.0)

      expect(meter_breakdown.meters_by_baseload).to match_array([meter_2, meter_1])
    end
  end

  describe '#enough_data?' do
    context 'when theres is a years worth' do
      it 'returns true' do
        expect(service.enough_data?).to be true
        expect(service.data_available_from).to be nil
      end
    end

    context 'when theres is limited data' do
      # acme academy has data starting in 2019-01-13
      let(:asof_date) { Date.new(2019, 1, 21) }

      before do
        allow_any_instance_of(AMRData).to receive(:end_date).and_return(asof_date)
      end

      it 'returns false' do
        expect(service.enough_data?).to be false
        expect(service.data_available_from).not_to be nil
      end
    end
  end
end
