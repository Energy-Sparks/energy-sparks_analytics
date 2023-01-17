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
      expect(annual_baseload_breakdowns[0].as_json).to eq(
        {
          'average_annual_baseload_kw' => -0.0,
          'meter_data_available_for_full_year' => false,
          'year' => 2019
        }
      )
      expect(annual_baseload_breakdowns[1].as_json).to eq(
        {
          'average_annual_baseload_kw' => 27.220618980169984,
          'meter_data_available_for_full_year' => true,
          'year' => 2020
        }
      )
      expect(annual_baseload_breakdowns[2].as_json).to eq(
        {
          'average_annual_baseload_kw' => 26.174109589041098,
          'meter_data_available_for_full_year' => true,
          'year' => 2021
        }
      )
      expect(annual_baseload_breakdowns[3].as_json).to eq(
        {
          'average_annual_baseload_kw' => 24.5531506849315,
          'meter_data_available_for_full_year' => false,
          'year' => 2022
        }
      )
    end
  end
end
