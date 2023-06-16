# frozen_string_literal: true
require 'pp'

require 'spec_helper'

describe SolarPhotovoltaics::PotentialBenefitsEstimatorService, type: :service do
  let(:service) { SolarPhotovoltaics::PotentialBenefitsEstimatorService.new(meter_collection: @acme_academy, asof_date: Date.parse('2020-12-31')) }

  # using before(:all) here to avoid slow loading of YAML and then
  # running the aggregation code for each test.
  before(:all) do
    @acme_academy = load_unvalidated_meter_collection(school: 'acme-academy')
  end

  context '#enough_data?' do
    it 'returns true if one years worth of data is available' do
      expect(service.enough_data?).to eq(true)
    end
  end

  context '#create_model' do
    it 'calculates the potential benefits over a geometric sequence of capacity kWp up to 256 for a school with no solar pv' do
      model = service.create_model

      expect(model.optimum_kwp).to round_to_two_digits(62.0)
      expect(model.optimum_payback_years).to round_to_two_digits(6.47)
      expect(model.optimum_mains_reduction_percent).to round_to_two_digits(0.12)
      expect(model.scenarios.size).to eq 9

      scenarios = model.scenarios

      expect(scenarios[0].kwp).to eq(1)
      expect(scenarios[0].panels).to eq(3)
      expect(scenarios[0].area).to eq(4)
      expect(scenarios[0].solar_consumed_onsite_kwh).to round_to_two_digits(893.95) # 893.9545973935678
      expect(scenarios[0].exported_kwh).to round_to_two_digits(0.0) # 0.0
      expect(scenarios[0].solar_pv_output_kwh).to round_to_two_digits(893.95) # 893.954597393567
      expect(scenarios[0].reduction_in_mains_percent * 100).to round_to_two_digits(0.21) # 0.002068165948887468
      expect(scenarios[0].mains_savings_£).to round_to_two_digits(140.17) # 140.1736542641811
      expect(scenarios[0].solar_pv_output_co2).to round_to_two_digits(169.23) # 169.23840876311736
      expect(scenarios[0].capital_cost_£).to round_to_two_digits(1584.0)
      expect(scenarios[0].payback_years).to round_to_two_digits(11.3)

      expect(scenarios[8].kwp).to eq(128)
      expect(scenarios[8].panels).to eq(427)
      expect(scenarios[8].area).to eq(615)
      expect(scenarios[8].solar_consumed_onsite_kwh).to round_to_two_digits(85201.53) # 85201.53193961504
      expect(scenarios[8].exported_kwh).to round_to_two_digits(29224.66) # 29224.65652676189
      expect(scenarios[8].solar_pv_output_kwh).to round_to_two_digits(114426.19) # 114426.18846637658
      expect(scenarios[8].reduction_in_mains_percent * 100).to round_to_two_digits(19.71) # 0.1971139335983544
      expect(scenarios[8].mains_savings_£).to round_to_two_digits(13326.38) # 13326.379573018603
      expect(scenarios[8].solar_pv_output_co2).to round_to_two_digits(21661.24) # 21661.23632167902
      expect(scenarios[8].capital_cost_£).to round_to_two_digits(99841.82)
      expect(scenarios[8].payback_years).to round_to_two_digits(6.75)
    end
  end
end
