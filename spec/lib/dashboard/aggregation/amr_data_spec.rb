require 'spec_helper'

describe AMRData do

  let(:start_date)    { Date.new(2023,1,1) }
  let(:end_date)      { Date.new(2023,1,31) }
  let(:kwh_data_x48)  { Array.new(48, 0.01) }

  subject(:amr_data)    { build(:amr_data, :with_days, day_count: 31, end_date: end_date, kwh_data_x48: kwh_data_x48) }

  describe '#check_type' do
    %i[kwh £ economic_cost co2 £current current_economic_cost accounting_cost].each do |type|
      it { amr_data.check_type(type) }
    end
    it { expect{amr_data.check_type(:unknown)}.to raise_error(AMRData::UnexpectedDataType) }
  end

  describe '#one_day_kwh' do
    it 'returns expected total' do
      expect(amr_data.one_day_kwh(start_date)).to be_within(0.0001).of(kwh_data_x48.sum)
    end
  end

  describe '#kwh_date_range' do
    it 'returns expected total' do
      expect(amr_data.kwh_date_range(start_date, end_date)).to be_within(0.0001).of(kwh_data_x48.sum * 31)
    end

    context 'post aggregation' do
      before do
        amr_data.set_post_aggregation_state
      end

      it 'returns expected total' do
        expect(amr_data.kwh_date_range(start_date, end_date)).to be_within(0.0001).of(kwh_data_x48.sum * 31)
        #confirm we are not recalculating
        expect(amr_data).to_not receive(:one_day_kwh)
        expect(amr_data.kwh_date_range(start_date, end_date)).to be_within(0.0001).of(kwh_data_x48.sum * 31)
      end

    end
  end
end
