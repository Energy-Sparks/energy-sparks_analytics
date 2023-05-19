require 'spec_helper'

describe Baseload::IntraweekBaseloadService, type: :service do

  let(:asof_date)      { Date.new(2022, 2, 1) }
  let(:meter)          { @acme_academy.aggregated_electricity_meters }
  let(:service)        { Baseload::IntraweekBaseloadService.new(meter, asof_date)}

  #using before(:all) here to avoid slow loading of YAML and then
  #running the aggregation code for each test.
  before(:all) do
    @acme_academy = load_unvalidated_meter_collection(school: 'acme-academy')
  end

  context '#intraweek_variation' do
    it 'calculates the variation' do
      intraweek_variation = service.intraweek_variation
      expect(intraweek_variation.min_day).to eq 6
      expect(intraweek_variation.max_day).to eq 4
      expect(intraweek_variation.min_day_kw).to round_to_two_digits(22.17)
      expect(intraweek_variation.max_day_kw).to round_to_two_digits(25.30)
      expect(intraweek_variation.percent_intraday_variation).to round_to_two_digits(0.14)
      expect(intraweek_variation.annual_cost_kwh).to round_to_two_digits(17775.79)
    end
  end

  context '#estimated_costs' do
    it 'calculates the costs' do
      costs = service.estimated_costs
      expect(costs.kwh).to round_to_two_digits(17775.79)
      expect(costs.co2).to round_to_two_digits(3365.01)
      expect(costs.£).to round_to_two_digits(2655.35)
    end
  end

  context '#enough_data?' do
    context 'when theres is a years worth' do
      it 'returns true' do
        expect( service.enough_data? ).to be true
      end
    end
    context 'when theres is limited data' do
      #acme academy has data starting in 2019-01-13
      let(:asof_date)      { Date.new(2019, 6, 1) }
      it 'returns false' do
        expect( service.enough_data? ).to be false
      end
    end
  end

end
