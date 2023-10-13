# frozen_string_literal: true

require 'spec_helper'
describe Costs::EconomicTariffsChangeCaveatsService do
  # using before(:all) here to avoid slow loading of YAML and then
  # running the aggregation code for each test.
  before(:all) do
    @acme_academy = load_unvalidated_meter_collection(school: 'acme-academy-exaggerated-tariffs')
  end

  context '#calculate_economic_tariff_changed' do
    xit 'calulates economic tariff changed data' do
      service = Costs::EconomicTariffsChangeCaveatsService.new(meter_collection: @acme_academy, fuel_type: :electricity)
      model = service.calculate_economic_tariff_changed

      expect(model.last_change_date).to eq(Date.new(2022, 9, 1))
      expect(model.percent_change).to round_to_two_digits(18.86) # 18.857098661736725
      expect(model.rate_after_£_per_kwh).to round_to_two_digits(3.07) # 3.066783066364631
      expect(model.rate_before_£_per_kwh).to round_to_two_digits(0.15) # 0.1544426564326899
    end
  end
end
