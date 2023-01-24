# frozen_string_literal: true

require 'spec_helper'

describe Heating::HeatingThermostaticAnalysisService do
  let(:service) { Heating::HeatingThermostaticAnalysisService.new(aggregated_heat_meters: @acme_academy.aggregated_heat_meters) }

  # using before(:all) here to avoid slow loading of YAML and then
  # running the aggregation code for each test.
  before(:all) do
    @acme_academy = load_unvalidated_meter_collection(school: 'acme-academy')
  end

  context '#create_model' do
    it 'creates a model for results of a heating thermostatic analysis' do
      model = service.create_model
      expect(model.r2).to round_to_two_digits(0.67) # 0.6743665142232793
      expect(model.insulation_hotwater_heat_loss_estimate_kwh).to round_to_two_digits(193133.95) # 193133.95130872616
      expect(model.insulation_hotwater_heat_loss_estimate_£).to round_to_two_digits(5794.02) # 5794.0185392617805
      expect(model.average_heating_school_day_a).to round_to_two_digits(5812.08) # 5812.076809865945
      expect(model.average_heating_school_day_b).to round_to_two_digits(-326.06) # -326.0646866043404
      expect(model.average_outside_temperature_high).to eq(12.0)
      expect(model.average_outside_temperature_low).to eq(4.0)
      expect(model.predicted_kwh_for_high_average_outside_temperature).to round_to_two_digits(1899.3) # 1899.3005706138597
      expect(model.predicted_kwh_for_low_average_outside_temperature).to round_to_two_digits(4507.82) # 4507.818063448583
    end
  end
end
