# frozen_string_literal: true

require 'spec_helper'

describe Baseload::AnnualBaseloadBreakdownService, type: :service do
  let(:service)        { Baseload::AnnualBaseloadBreakdownService.new(@acme_academy) }

  # using before(:all) here to avoid slow loading of YAML and then
  # running the aggregation code for each test.
  before(:all) do
    @acme_academy = load_unvalidated_meter_collection(school: 'acme-academy')
  end

  context '#calculate_annual_baseload_breakdowns' do
    it 'runs the calculation' do
      expect(service.calculate_annual_baseload_breakdowns).to eq(
        [
          {
            mpan_mprn: 1_591_058_886_735,
            year_averages: [
              { 
                average_annual_baseload_cost_in_pounds_sterling: nil,
                average_annual_baseload_kw: 4.780737704918032,
                average_annual_co2_emissions: nil,
                year: 2020
              },
              { 
                average_annual_baseload_cost_in_pounds_sterling: nil,
                average_annual_baseload_kw: 4.905205479452056,
                average_annual_co2_emissions: nil,
                year: 2021
              },
              { 
                average_annual_baseload_cost_in_pounds_sterling: nil,
                average_annual_baseload_kw: nil,
                average_annual_co2_emissions: nil,
                year: 2022
              },
              { 
                average_annual_baseload_cost_in_pounds_sterling: nil,
                average_annual_baseload_kw: nil,
                average_annual_co2_emissions: nil,
                year: 2023
              }
            ]
          },
          {
            mpan_mprn: 1_580_001_320_420,
            year_averages: [
              { 
                average_annual_baseload_cost_in_pounds_sterling: nil,
                average_annual_baseload_kw: 20.882445355191255,
                average_annual_co2_emissions: nil,
                year: 2020
              },
              { 
                average_annual_baseload_cost_in_pounds_sterling: nil,
                average_annual_baseload_kw: 19.085547945205462,
                average_annual_co2_emissions: nil,
                year: 2021
              },
              { 
                average_annual_baseload_cost_in_pounds_sterling: nil,
                average_annual_baseload_kw: nil,
                average_annual_co2_emissions: nil,
                year: 2022
              },
              {
                average_annual_baseload_cost_in_pounds_sterling: nil,
                average_annual_baseload_kw: nil,
                average_annual_co2_emissions: nil,
                year: 2023
              }
            ]
          }
        ]
      )
    end
  end
end
