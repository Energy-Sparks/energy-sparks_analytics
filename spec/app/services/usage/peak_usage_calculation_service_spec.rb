# frozen_string_literal: true

require 'spec_helper'

describe Usage::PeakUsageCalculationService, type: :service do
  Object.const_set('Rails', true) # Otherwise the test fails at line 118 (RecordTestTimes) in ChartManager

  let(:meter_collection)          { @acme_academy }

  before(:all) do
    @acme_academy = load_unvalidated_meter_collection(school: 'acme-academy')
  end

  context '#average_school_day_peak_usage_kw' do
    it 'calculates the average school day peak usage in kw from a given asof date' do
      service = Usage::PeakUsageCalculationService.new(
        meter_collection: meter_collection,
        asof_date: Date.new(2022, 1, 1)
      )
      model = service.calculate_peak_usage
      expect(model.average_school_day_last_year_kw).to round_to_two_digits(135.92) # 135.9213058419244
      expect(model.average_school_day_last_year_kw_per_pupil).to round_to_two_digits(0.14) # 0.14143736299888077
      expect(model.average_school_day_last_year_kw_per_floor_area).to round_to_two_digits(0.02) # 0.02291323429567168
    end
  end
end
