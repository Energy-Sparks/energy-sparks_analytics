# frozen_string_literal: true
require 'pp'

require 'spec_helper'

describe SolarPhotovoltaics::ExistingBenefitsService, type: :service do
  let(:service) { SolarPhotovoltaics::ExistingBenefitsService.new(meter_collection: @acme_academy, asof_date: Date.parse('2020-12-31')) }

  # using before(:all) here to avoid slow loading of YAML and then
  # running the aggregation code for each test.
  before(:all) do
    @acme_academy = load_unvalidated_meter_collection(school: 'acme-academy')
  end

  context '#calculate' do
    it 'calculates the existing benefits for a school with solar pv' do

    end
  end
end
