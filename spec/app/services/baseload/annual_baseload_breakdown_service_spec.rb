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
            mpan_mprn: 1_591_058_886_735,
            year_averages: [
              { 
                average_annual_baseload_cost_in_pounds_sterling: 6299.099999999999,
                average_annual_baseload_kw: 4.780737704918032,
                average_annual_co2_emissions: 1.0995696721311474,
                year: 2020
              },
              { 
                average_annual_baseload_cost_in_pounds_sterling: 6444.94125,
                average_annual_baseload_kw: 4.905205479452056,
                average_annual_co2_emissions: 1.128197260273973,
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
                average_annual_baseload_cost_in_pounds_sterling: 27408.915,
                average_annual_baseload_kw: 20.882445355191255,
                average_annual_co2_emissions: 4.802962431693989,
                year: 2020
              },
              { 
                average_annual_baseload_cost_in_pounds_sterling: 24937.278,
                average_annual_baseload_kw: 19.085547945205462,
                average_annual_co2_emissions: 4.389676027397257,
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
