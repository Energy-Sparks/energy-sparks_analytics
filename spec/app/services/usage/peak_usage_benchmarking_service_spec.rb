# frozen_string_literal: true

require 'spec_helper'

describe Usage::PeakUsageBenchmarkingService, type: :service do
  Object.const_set('Rails', true) # Otherwise the test fails at line 118 (RecordTestTimes) in ChartManager

  let(:meter_collection)          { @acme_academy }

  before(:all) do
    @acme_academy = load_unvalidated_meter_collection(school: 'acme-academy')
  end

  # rubocop:disable Layout/LineLength
  context '' do
    it '' do
      service = Usage::PeakUsageBenchmarkingService.new(
        meter_collection: meter_collection,
        asof_date: Date.new(2022, 1, 1)
      )

      model = service.calculate_average_school_day_peak_usage_kw_comparison

      expect(model.average_school_day_peak_usage_kw.average_school_day_last_year_kw).to round_to_two_digits(135.92) # 135.9213058419244
      expect(model.average_school_day_peak_usage_kw.average_school_day_last_year_kw_per_pupil).to round_to_two_digits(0.14) # 0.14143736299888077
      expect(model.average_school_day_peak_usage_kw.average_school_day_last_year_kw_per_floor_area).to round_to_two_digits(0.02) # 0.02291323429567168

      expect(model.potential_saving.co2).to round_to_two_digits(21_048.32) # 21048.319799999976
      expect(model.potential_saving.kwh).to round_to_two_digits(105_187.78) # 105187.77999999828
      expect(model.potential_saving.£).to round_to_two_digits(16_440.45) # 16440.45410541508
      expect(model.potential_saving.percent).to eq(nil)
    end
  end
  # rubocop:enable Layout/LineLength
end
