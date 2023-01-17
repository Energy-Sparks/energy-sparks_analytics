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
end
