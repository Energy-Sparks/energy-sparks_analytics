require 'spec_helper'

describe Baseload::BaseloadCalculationService, type: :service do

  let(:asof_date)      { Date.new(2022, 2, 1) }
  let(:service)        { Baseload::BaseloadMeterBreakdownService.new(@acme_academy)}

  let(:meter_1)        { 1591058886735 }
  let(:meter_2)        { 1580001320420 }

  #using before(:all) here to avoid slow loading of YAML and then
  #running the aggregation code for each test.
  before(:all) do
    @acme_academy = load_unvalidated_meter_collection(school: 'acme-academy')
  end

  context '#calculate_breakdown' do

    it 'runs the calculation' do
      meter_breakdown = service.calculate_breakdown
      expect(meter_breakdown.meters).to match_array([meter_1, meter_2])
      expect(meter_breakdown.baseload_kw(meter_1)).to_not be_nil
      expect(meter_breakdown.percentage_baseload(meter_1)).to_not be_nil
      expect(meter_breakdown.baseload_cost_£(meter_1)).to_not be_nil

      kw_1 = meter_breakdown.baseload_kw(meter_1)
      kw_2 = meter_breakdown.baseload_kw(meter_2)
      expect(meter_breakdown.total_baseload_kw).to eq(kw_1+kw_2)

      perc_1 = meter_breakdown.percentage_baseload(meter_1)
      perc_2 = meter_breakdown.percentage_baseload(meter_2)
      expect(perc_1+perc_2).to eq(1.0)

      expect(meter_breakdown.meters_by_baseload).to match_array([meter_2, meter_1])
    end
  end
end
