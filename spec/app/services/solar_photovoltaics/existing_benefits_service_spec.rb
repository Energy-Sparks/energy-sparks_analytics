# frozen_string_literal: true
require 'spec_helper'

describe SolarPhotovoltaics::ExistingBenefitsService, type: :service do
  let(:service) { SolarPhotovoltaics::ExistingBenefitsService.new(meter_collection: @acme_academy) }

  # using before(:all) here to avoid slow loading of YAML and then
  # running the aggregation code for each test.
  before(:all) do
    @acme_academy = load_unvalidated_meter_collection(school: 'acme-academy-with-solar')
  end

  context '#enough_data?' do
    it 'returns true if one years worth of data is available' do
      expect(service.enough_data?).to eq(true)
    end
  end

  context '#create_model' do
    it 'calculates the existing benefits for a school with solar pv' do
      benefits = service.create_model
      expect(benefits.annual_saving_from_solar_pv_percent).to round_to_two_digits(0.19)
      expect(benefits.annual_electricity_including_onsite_solar_pv_consumption_kwh).to round_to_two_digits(59574.02)
      expect(benefits.annual_carbon_saving_percent).to round_to_two_digits(0.23)
      expect(benefits.saving_£current).to round_to_two_digits(1712.49)
      expect(benefits.export_£).to round_to_two_digits(100.12)
      expect(benefits.annual_co2_saving_kg).to round_to_two_digits(2541.83)

      # summary table of electricity usage for the last year
      expect(benefits.annual_solar_pv_kwh).to round_to_two_digits(13977.89)
      expect(benefits.annual_exported_solar_pv_kwh).to round_to_two_digits(2002.43)
      expect(benefits.annual_solar_pv_consumed_onsite_kwh).to round_to_two_digits(11416.62)
      expect(benefits.annual_consumed_from_national_grid_kwh).to round_to_two_digits(48157.40)
    end
  end
end
