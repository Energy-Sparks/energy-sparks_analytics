# frozen_string_literal: true

require 'spec_helper'

describe Usage::PeakUsageBenchmarkingService, type: :service do
  Object.const_set('Rails', true) # Otherwise the test fails at line 118 (RecordTestTimes) in ChartManager

  let(:meter_collection)          { @acme_academy }

  before(:all) do
    @acme_academy = load_unvalidated_meter_collection(school: 'acme-academy')
  end

  context '#average_school_day_peak_usage_kw' do
    it 'calculates the average school day peak usage in kw from a given asof date' do
      service = Usage::PeakUsageBenchmarkingService.new(meter_collection: meter_collection, asof_date: Date.today - 365)
      expect(service.average_school_day_peak_usage_kw).to eq(148.3508591065292)
    end
  end
end
