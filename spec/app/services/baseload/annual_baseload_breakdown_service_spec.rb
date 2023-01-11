# frozen_string_literal: true

require 'spec_helper'

describe Baseload::AnnualBaseloadBreakdownService, type: :service do
  let(:service)        { Baseload::AnnualBaseloadBreakdownService.new(@acme_academy) }

  before(:all) do
    @acme_academy = load_unvalidated_meter_collection(school: 'acme-academy')
  end

  context '#annual_baseload_breakdowns' do
    it 'runs the calculation' do
      expect(service.annual_baseload_breakdowns).to eq(
        [
          {
            :average_annual_baseload_cost_in_pounds_sterling=>nil,
            :average_annual_baseload_kw=>nil,
            :average_annual_co2_emissions=>nil,
            :year=>2019
          },
          {
            :average_annual_baseload_cost_in_pounds_sterling=>34416.41494083075,
            :average_annual_baseload_kw=>26.190163934426238,
            :average_annual_co2_emissions=>nil,
            :year=>2020
          },
          {
            :average_annual_baseload_cost_in_pounds_sterling=>32139.10057231434,
            :average_annual_baseload_kw=>24.5531506849315,
            :average_annual_co2_emissions=>nil,
            :year=>2021
          },
          {
            :average_annual_baseload_cost_in_pounds_sterling=>nil,
            :average_annual_baseload_kw=>nil,
            :average_annual_co2_emissions=>nil,
            :year=>2022
          }
        ]
      )
    end
  end
end
