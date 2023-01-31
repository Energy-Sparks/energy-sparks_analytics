# frozen_string_literal: true

require 'spec_helper'

describe Usage::UsagePeriodComparisonService, type: :service do
  let(:service) do
    Usage::UsagePeriodComparisonService.new(
      meter_collection: @acme_academy,
      fuel_type: :electricity,
      date: Date.new(2021, 1, 31)
    )
  end

  # using before(:all) here to avoid slow loading of YAML and then
  # running the aggregation code for each test.
  before(:all) do
    @acme_academy = load_unvalidated_meter_collection(school: 'acme-academy')
  end

  context '#create_model' do
    it 'creates a model for results of a baseload period comparison' do
      model = service.create_model
      expect(model.current_period_start_date).to eq(Date.new(2021, 1, 18))
      expect(model.previous_period_start_date).to eq(Date.new(2021, 1, 11))
    end
  end
end
