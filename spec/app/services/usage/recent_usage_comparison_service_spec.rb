# frozen_string_literal: true

require 'spec_helper'

# rubocop:disable Metrics/BlockLength
describe Usage::RecentUsageComparisonService, type: :service do
  let(:service) do
    Usage::RecentUsageComparisonService.new(
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

      expect(model.last_4_school_weeks.date_range).to eq([Date.new(2022, 6, 12), Date.new(2022, 7, 9)])
      expect(model.last_4_school_weeks.results.kwh).to round_to_two_digits(7817.13) # 7817.125
      expect(model.last_4_school_weeks.results.£).to round_to_two_digits(1172.57) # 1172.56875
      expect(model.last_4_school_weeks.results.co2).to round_to_two_digits(1524.17) # 1524.167925

      expect(model.previous_4_school_weeks.date_range).to eq([Date.new(2022, 5, 8), Date.new(2022, 6, 11)])
      expect(model.previous_4_school_weeks.results.kwh).to round_to_two_digits(8374.28) # 8374.275
      expect(model.previous_4_school_weeks.results.£).to round_to_two_digits(1256.14) # 1256.1412500000001
      expect(model.previous_4_school_weeks.results.co2).to round_to_two_digits(1333.14) # 1333.136225

      expect(model.recent_usage_comparison.kwh).to round_to_two_digits(557.15) # 557.1499999999996
      expect(model.recent_usage_comparison.£).to round_to_two_digits(83.57) # 83.57250000000022
      expect(model.recent_usage_comparison.co2).to round_to_two_digits(-191.03) # -191.0317
      expect(model.recent_usage_comparison.percent).to round_to_two_digits(-0.07) # -0.06653113254580244
    end
  end
end
# rubocop:enable Metrics/BlockLength
