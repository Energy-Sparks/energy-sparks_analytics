# frozen_string_literal: true

require 'spec_helper'

describe Costs::MonthlyMeterCostsService do
  let(:service) { Costs::MonthlyMeterCostsService.new(meter: @acme_academy.electricity_meters.first) }

  # using before(:all) here to avoid slow loading of YAML and then
  # running the aggregation code for each test.
  before(:all) do
    @acme_academy = load_unvalidated_meter_collection(school: 'acme-academy')
  end

  context '#create_model' do
    it 'creates a model for results of a costs analysis' do
      model = service.create_model
      expect(model.count).to eq(43)
      expect(model.first.month_start_date).to eq(Date.parse('2019-01-01'))
      expect(model.first.start_date).to eq(Date.parse('2019-01-13'))
      expect(model.first.end_date).to eq(Date.parse('2019-01-31'))
      expect(model.first.bill_component_costs.keys.sort).to eq(%i[flat_rate standing_charge])
      expect(model.first.bill_component_costs[:flat_rate]).to round_to_two_digits(1554.26) # 1554.2571449999998
      expect(model.first.bill_component_costs[:standing_charge]).to round_to_two_digits(19.0) # 19.0
      expect(model.first.full_month).to eq(false)
      expect(model.first.total).to eq(model.first.bill_component_costs[:flat_rate] + model.first.bill_component_costs[:standing_charge])

      expect(model.last.month_start_date).to eq(Date.parse('2022-07-01'))
      expect(model.last.start_date).to eq(Date.parse('2022-07-01'))
      expect(model.last.end_date).to eq(Date.parse('2022-07-13'))
      expect(model.last.bill_component_costs.keys.sort).to eq(%i[flat_rate standing_charge])
      expect(model.last.bill_component_costs[:flat_rate]).to round_to_two_digits(394.83) # 394.83000000000004
      expect(model.last.bill_component_costs[:standing_charge]).to round_to_two_digits(13.0) # 13.0
      expect(model.last.full_month).to eq(false)
      expect(model.last.total).to eq(model.last.bill_component_costs[:flat_rate] + model.last.bill_component_costs[:standing_charge])
    end
  end
end
