# frozen_string_literal: true
require 'pp'

require 'spec_helper'

describe SolarPhotovoltaics::ExistingBenefitsService, type: :service do
  let(:service) { SolarPhotovoltaics::ExistingBenefitsService.new(meter_collection: @acme_academy) }

  # using before(:all) here to avoid slow loading of YAML and then
  # running the aggregation code for each test.
  before(:all) do
    @acme_academy = load_unvalidated_meter_collection(school: 'acme-academy-with-solar')
  end

  context '#calculate' do
    it 'calculates the existing benefits for a school with solar pv' do
      benefits = service.calculate
      expect(benefits.annual_saving_from_solar_pv_percent).to round_to_two_digits(0.21) # 0.2112828204597476
      expect(benefits.annual_electricity_including_onsite_solar_pv_consumption_kwh).to round_to_two_digits(61057.88) # 61057.88139174447
      expect(benefits.annual_carbon_saving_percent).to round_to_two_digits(0.23) # 0.2324996269349433
      expect(benefits.saving_£current).to round_to_two_digits(1935.07) # 1935.0722087616766
      expect(benefits.export_£).to round_to_two_digits(64.77) # 64.77266266370466
      expect(benefits.annual_co2_saving_kg).to round_to_two_digits(2541.83) # 2541.832811649812

      # summary table of electricity usage for the last year
      expect(benefits.annual_solar_pv_kwh).to round_to_two_digits(14195.93) # 14195.934645018606
      expect(benefits.annual_exported_solar_pv_kwh).to round_to_two_digits(1295.45) # 1295.4532532740932
      expect(benefits.annual_solar_pv_consumed_onsite_kwh).to round_to_two_digits(12900.48) # 12900.481391744512
      expect(benefits.annual_consumed_from_national_grid_kwh).to round_to_two_digits(48157.40) # 48157.39999999996
    end
  end
end
