# frozen_string_literal: true

require 'spec_helper'

# rubocop:disable Metrics/BlockLength
describe Usage::RecentUsagePeriodCalculationService, type: :service do
  let(:service) do
    Usage::RecentUsagePeriodCalculationService.new(
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

  context '#recent_usage' do
    it 'creates a resent usage object for results of a baseload period comparison for a given schoolweek range' do
      model = service.recent_usage({schoolweek: -3..0})
      expect(model.date_range).to eq([Date.new(2022, 6, 12), Date.new(2022, 7, 9)])
      expect(model.combined_usage_metric.kwh).to round_to_two_digits(31268.5) # 31268.5
      expect(model.combined_usage_metric.£).to round_to_two_digits(4690.28) # 4690.275
      expect(model.combined_usage_metric.co2).to round_to_two_digits(6096.67) # 6096.6717

      model = service.recent_usage({schoolweek: -7..-4})
      expect(model.date_range).to eq([Date.new(2022, 5, 8), Date.new(2022, 6, 11)])
      expect(model.combined_usage_metric.kwh).to round_to_two_digits(33497.1) # 33497.1
      expect(model.combined_usage_metric.£).to round_to_two_digits(5024.57) # 5024.5650000000005
      expect(model.combined_usage_metric.co2).to round_to_two_digits(5332.54) # 5332.5449
    end

    it 'creates a resent usage object for results of a baseload period comparison for a given date range' do
      model = service.recent_usage({daterange: Date.new(2022, 6, 12)..Date.new(2022, 7, 9)})
      expect(model.date_range).to eq([Date.new(2022, 6, 12), Date.new(2022, 7, 9)])
      expect(model.combined_usage_metric.kwh).to round_to_two_digits(31268.5) # 31268.5
      expect(model.combined_usage_metric.£).to round_to_two_digits(4690.28) # 4690.275
      expect(model.combined_usage_metric.co2).to round_to_two_digits(6096.67) # 6096.6717

      model = service.recent_usage({daterange: Date.new(2022, 5, 8)..Date.new(2022, 6, 11)})
      expect(model.date_range).to eq([Date.new(2022, 5, 8), Date.new(2022, 6, 11)])
      expect(model.combined_usage_metric.kwh).to round_to_two_digits(33497.1) # 33497.1
      expect(model.combined_usage_metric.£).to round_to_two_digits(5024.57) # 5024.5650000000005
      expect(model.combined_usage_metric.co2).to round_to_two_digits(5332.54) # 5332.5449
    end
  end
end