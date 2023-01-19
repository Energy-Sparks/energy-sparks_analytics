# frozen_string_literal: true
require 'pp'

require 'spec_helper'

describe SolarPhotovoltaics::ExistingBenefitsService, type: :service do
  let(:service) { SolarPhotovoltaics::ExistingBenefitsService.new(meter_collection: @acme_academy) }

  # using before(:all) here to avoid slow loading of YAML and then
  # running the aggregation code for each test.
  before(:all) do
    @acme_academy = load_unvalidated_meter_collection(school: 'acme-academy-with-solar')
  end

  context '#calculate' do
    it 'calculates the existing benefits for a school with solar pv' do
      benefits = service.calculate
      expect(benefits.annual_saving_from_solar_pv_percent).to eq(0.2112828204597476)
    end
  end
end
