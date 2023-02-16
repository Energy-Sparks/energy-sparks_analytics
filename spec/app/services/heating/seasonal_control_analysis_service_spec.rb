# frozen_string_literal: true

require 'spec_helper'

describe Heating::SeasonalControlAnalysisService do
  let(:service) { Heating::SeasonalControlAnalysisService.new(meter_collection: @acme_academy) }

  # using before(:all) here to avoid slow loading of YAML and then
  # running the aggregation code for each test.
  before(:all) do
    @acme_academy = load_unvalidated_meter_collection(school: 'acme-academy')
  end

  context '#enough_data?' do
    context 'when theres is a years worth' do
      it 'returns true' do
        expect( service.enough_data? ).to be true
        expect( service.data_available_from).to be nil
      end
    end
    context 'when theres is limited data' do
      #acme academy has gas data starting in 2018-09-01
      let(:asof_date)      { Date.new(2019, 6, 13) }
      before(:each) do
        allow_any_instance_of(AMRData).to receive(:end_date).and_return(asof_date)
      end
      it 'returns false' do
        expect( service.enough_data? ).to be false
        expect( service.data_available_from).to_not be nil
      end
    end
  end

  context '#seasonal_analysis' do
    it 'produces expected seasonal control analysis' do
      seasonal_analysis = service.seasonal_analysis
      expect(seasonal_analysis.estimated_savings.kwh).to round_to_two_digits(19_909.44) # 19_909.43570393906
      expect(seasonal_analysis.estimated_savings.£).to round_to_two_digits(597.28) # 597.2830711181718
      expect(seasonal_analysis.estimated_savings.co2).to round_to_two_digits(4180.98) # 4180.9814978272025
      expect(seasonal_analysis.heating_on_in_warm_weather_days).to round_to_two_digits(18.0) # 18.0

      #extracted expected value here by running the old advice
      #page and dumping variable from AlertSeasonalHeatingSchoolDays
      #this uses a different set of date ranges, than if you run
      #the alert separately.
      expect(seasonal_analysis.percent_of_annual_heating).to round_to_two_digits(0.07) #0.06966199972329139
    end
  end
end
