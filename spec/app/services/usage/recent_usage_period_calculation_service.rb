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
    it 'creates a resent usage object for results of a baseload period comparison for a given period range' do
      model = service.recent_usage(period_range: -3..0)
      expect(model.date_range).to eq([Date.new(2022, 6, 12), Date.new(2022, 7, 9)])
      expect(model.combined_usage_metric.kwh).to round_to_two_digits(7817.13) # 7817.125
      expect(model.combined_usage_metric.£).to round_to_two_digits(1172.57) # 1172.56875
      expect(model.combined_usage_metric.co2).to round_to_two_digits(1524.17) # 1524.167925

      model = service.recent_usage(period_range: -7..-4)
      expect(model.date_range).to eq([Date.new(2022, 5, 8), Date.new(2022, 6, 11)])
      expect(model.combined_usage_metric.kwh).to round_to_two_digits(8374.28) # 8374.275
      expect(model.combined_usage_metric.£).to round_to_two_digits(1256.14) # 1256.1412500000001
      expect(model.combined_usage_metric.co2).to round_to_two_digits(1333.14) # 1333.136225
    end
  end
end