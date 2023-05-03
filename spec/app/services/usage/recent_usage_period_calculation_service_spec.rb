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
    it 'creates a recent usage object for results of a baseload period comparison for a period in the last week by date range and schoolweek' do
      model = service.recent_usage({schoolweek: 0..0})
      expect(model.date_range).to eq([Date.new(2022, 7, 3), Date.new(2022, 7, 9)])
      expect((model.date_range.first..model.date_range.last).to_a.size).to eq(7)
      expect(model.date_range.first.sunday?).to eq(true)
      expect(model.date_range.last.saturday?).to eq(true)
      expect(model.combined_usage_metric.kwh).to round_to_two_digits(7839.8) # 7839.800000000001
      expect(model.combined_usage_metric.£).to round_to_two_digits(1175.97) # 1175.9699999999998
      expect(model.combined_usage_metric.co2).to round_to_two_digits(1445.52) # 1445.5187999999998

      model = service.recent_usage({daterange: Date.new(2022, 7, 3)..Date.new(2022, 7, 9)})
      expect(model.date_range).to eq([Date.new(2022, 7, 3), Date.new(2022, 7, 9)])
      expect((model.date_range.first..model.date_range.last).to_a.size).to eq(7)
      expect(model.date_range.first.sunday?).to eq(true)
      expect(model.date_range.last.saturday?).to eq(true)
      expect(model.combined_usage_metric.kwh).to round_to_two_digits(7839.8) # 7839.800000000001
      expect(model.combined_usage_metric.£).to round_to_two_digits(1175.97) # 1175.9699999999998
      expect(model.combined_usage_metric.co2).to round_to_two_digits(1445.52) # 1445.5187999999998
    end

    it 'creates a recent usage object for results of a baseload period comparison for a period in the previous week by date range and schoolweek' do
      model = service.recent_usage({schoolweek: -1..-1})
      expect(model.date_range).to eq([Date.new(2022, 6, 26), Date.new(2022, 7, 2)])
      expect((model.date_range.first..model.date_range.last).to_a.size).to eq(7)
      expect(model.date_range.first.sunday?).to eq(true)
      expect(model.date_range.last.saturday?).to eq(true)
      expect(model.combined_usage_metric.kwh).to round_to_two_digits(8150.0) # 8149.999999999999
      expect(model.combined_usage_metric.£).to round_to_two_digits(1222.5) # 1222.5
      expect(model.combined_usage_metric.co2).to round_to_two_digits(1625.02) # 1625.0184

      model = service.recent_usage({daterange: Date.new(2022, 6, 26)..Date.new(2022, 7, 2)})
      expect(model.date_range).to eq([Date.new(2022, 6, 26), Date.new(2022, 7, 2)])
      expect((model.date_range.first..model.date_range.last).to_a.size).to eq(7)
      expect(model.date_range.first.sunday?).to eq(true)
      expect(model.date_range.last.saturday?).to eq(true)
      expect(model.combined_usage_metric.kwh).to round_to_two_digits(8150.0) # 8149.999999999999
      expect(model.combined_usage_metric.£).to round_to_two_digits(1222.5) # 1222.5
      expect(model.combined_usage_metric.co2).to round_to_two_digits(1625.02) # 1625.0184
    end
  end

  context '#recent_usage' do
    it 'creates a recent usage object for results of a baseload period comparison for a period in the recent past by date range and schoolweek' do
      model = service.recent_usage({schoolweek: -3..0})
      expect(model.date_range).to eq([Date.new(2022, 6, 12), Date.new(2022, 7, 9)])
      expect((model.date_range.first..model.date_range.last).to_a.size).to eq(28)
      expect(model.date_range.first.sunday?).to eq(true)
      expect(model.date_range.last.saturday?).to eq(true)
      expect(model.combined_usage_metric.kwh).to round_to_two_digits(31268.5) # 31268.5
      expect(model.combined_usage_metric.£).to round_to_two_digits(4690.28) # 4690.275
      expect(model.combined_usage_metric.co2).to round_to_two_digits(6096.67) # 6096.6717

      model = service.recent_usage({daterange: Date.new(2022, 6, 12)..Date.new(2022, 7, 9)})
      expect(model.date_range).to eq([Date.new(2022, 6, 12), Date.new(2022, 7, 9)])
      expect((model.date_range.first..model.date_range.last).to_a.size).to eq(28)
      expect(model.date_range.first.sunday?).to eq(true)
      expect(model.date_range.last.saturday?).to eq(true)
      expect(model.combined_usage_metric.kwh).to round_to_two_digits(31268.5) # 31268.5
      expect(model.combined_usage_metric.£).to round_to_two_digits(4690.28) # 4690.275
      expect(model.combined_usage_metric.co2).to round_to_two_digits(6096.67) # 6096.6717
    end

    it 'creates a recent usage object for results of a baseload period comparison for a period in the far past by date range and schoolweek' do
      model = service.recent_usage({schoolweek: -6..-4})
      expect(model.date_range).to eq([Date.new(2022, 5, 15), Date.new(2022, 6, 11)])
      expect((model.date_range.first..model.date_range.last).to_a.size).to eq(28)
      expect(model.date_range.first.sunday?).to eq(true)
      expect(model.date_range.last.saturday?).to eq(true)
      expect(model.combined_usage_metric.kwh).to round_to_two_digits(24686.9) # 24686.899999999998
      expect(model.combined_usage_metric.£).to round_to_two_digits(3703.04) # 3703.035
      expect(model.combined_usage_metric.co2).to round_to_two_digits(4076.35) # 4076.3522999999996

      model = service.recent_usage({daterange: Date.new(2022, 5, 15)..Date.new(2022, 6, 11)})
      expect(model.date_range).to eq([Date.new(2022, 5, 15), Date.new(2022, 6, 11)])
      expect((model.date_range.first..model.date_range.last).to_a.size).to eq(28)
      expect(model.date_range.first.sunday?).to eq(true)
      expect(model.date_range.last.saturday?).to eq(true)
      expect(model.combined_usage_metric.kwh).to round_to_two_digits(24686.9) # 24686.899999999998
      expect(model.combined_usage_metric.£).to round_to_two_digits(3703.04) # 3703.035
      expect(model.combined_usage_metric.co2).to round_to_two_digits(4076.35) # 4076.3522999999996
    end
  end
end