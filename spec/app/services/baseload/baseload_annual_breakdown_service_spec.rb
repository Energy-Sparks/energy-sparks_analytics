# frozen_string_literal: true

require 'spec_helper'
require 'active_support/core_ext'

describe Baseload::BaseloadAnnualBreakdownService, type: :service do
  let(:service) { Baseload::BaseloadAnnualBreakdownService.new(@acme_academy) }

  before(:all) do
    @acme_academy = load_unvalidated_meter_collection(school: 'acme-academy')
  end

  context '#annual_baseload_breakdowns' do
    it 'runs the calculation' do
      annual_baseload_breakdowns = service.annual_baseload_breakdowns
      expect(annual_baseload_breakdowns.size).to eq(4)
      expect(annual_baseload_breakdowns.map(&:class).uniq).to eq([Baseload::AnnualBaseloadBreakdown])

      expect(annual_baseload_breakdowns[0].year).to eq(2019)
      expect(annual_baseload_breakdowns[0].average_annual_baseload_kw).to round_to_two_digits(0) # -0.0
      expect(annual_baseload_breakdowns[0].meter_data_available_for_full_year).to eq(false)

      expect(annual_baseload_breakdowns[1].year).to eq(2020)
      expect(annual_baseload_breakdowns[1].average_annual_baseload_kw).to round_to_two_digits(27.22) # 27.220618980169984
      expect(annual_baseload_breakdowns[1].meter_data_available_for_full_year).to eq(true)

      expect(annual_baseload_breakdowns[2].year).to eq(2021)
      expect(annual_baseload_breakdowns[2].average_annual_baseload_kw).to round_to_two_digits(26.17) # 26.174109589041098
      expect(annual_baseload_breakdowns[2].meter_data_available_for_full_year).to eq(true)

      expect(annual_baseload_breakdowns[3].year).to eq(2022)
      expect(annual_baseload_breakdowns[3].average_annual_baseload_kw).to round_to_two_digits(24.55) # 24.5531506849315
      expect(annual_baseload_breakdowns[3].meter_data_available_for_full_year).to eq(false)
    end
  end

  context '#enough_data?' do
    context 'when theres is a years worth' do
      it 'returns true' do
        expect( service.enough_data? ).to be true
        expect( service.data_available_from).to be nil
      end
    end
    context 'when theres is limited data' do
      #acme academy has data starting in 2019-01-13
      let(:asof_date)      { Date.new(2019, 1, 21) }
      before(:each) do
        allow_any_instance_of(AMRData).to receive(:end_date).and_return(asof_date)
      end
      it 'returns false' do
        expect( service.enough_data? ).to be false
        expect( service.data_available_from).to_not be nil
      end
    end
  end
end
